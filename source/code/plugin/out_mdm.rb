#!/usr/local/bin/ruby
# frozen_string_literal: true

module Fluent

  class OutputMDM < BufferedOutput

    config_param :retry_mdm_post_wait_minutes, :integer

    Plugin.register_output('out_mdm', self)

    def initialize
      super
      require 'net/http'
      require 'net/https'
      require 'uri'
      require 'json'
      require_relative 'KubernetesApiClient'
      require_relative 'ApplicationInsightsUtility'

      @@token_resource_url = 'https://monitoring.azure.com/'
      @@grant_type = 'client_credentials'
      @@azure_json_path = '/etc/kubernetes/host/azure.json'
      @@post_request_url_template = "https://%{aks_region}.monitoring.azure.com%{aks_resource_id}/metrics"
      @@token_url_template = "https://login.microsoftonline.com/%{tenant_id}/oauth2/token"
      @@plugin_name = "AKSCustomMetricsMDM"
      
      @data_hash = {}
      @token_url = nil
      @http_client = nil
      @token_expiry_time = Time.now
      @cached_access_token = String.new
      @last_post_attempt_time = Time.now
      @first_post_attempt_made = false
      @can_send_data_to_mdm = true
    end

    def configure(conf)
      s = conf.add_element("secondary")
      s["type"] = ChunkErrorHandler::SecondaryName
      super
    end

    def start
      super
      begin
        file = File.read(@@azure_json_path)
      rescue => e
        @log.info "Unable to read file #{@@azure_json_path} #{e}"
        @can_send_data_to_mdm = false
        return
      end
      # Handle the case where the file read fails. Send Telemetry and exit the plugin? 
      @data_hash = JSON.parse(file)
      @token_url = @@token_url_template % {tenant_id: @data_hash['tenantId']}
      @cached_access_token = get_access_token
      aks_resource_id = ENV['AKS_RESOURCE_ID']
      aks_region = ENV['AKS_REGION']
      if aks_resource_id.to_s.empty?
        @log.info "Environment Variable AKS_RESOURCE_ID is not set.. "
        @can_send_data_to_mdm = false
        return
      end
      if aks_region.to_s.empty?
        @log.info "Environment Variable AKS_REGION is not set.. "
        @can_send_data_to_mdm = false
        return
      end

      @@post_request_url = @@post_request_url_template % {aks_region: aks_region, aks_resource_id: aks_resource_id}
      @post_request_uri = URI.parse(@@post_request_url)
      @http_client = Net::HTTP.new(@post_request_uri.host, @post_request_uri.port)
      @http_client.use_ssl = true
      @log.info "POST Request url: #{@@post_request_url}"
      ApplicationInsightsUtility.sendCustomEvent("AKSCustomMetricsMDMPluginStart", {})
    end

    # get the access token only if the time to expiry is less than 5 minutes
    def get_access_token
      if @cached_access_token.to_s.empty? || (Time.now + 5*60 > @token_expiry_time) # token is valid for 60 minutes. Refresh token 5 minutes from expiration
        @log.info "Refreshing access token for out_mdm plugin.."
        token_uri = URI.parse(@token_url)
        http_access_token = Net::HTTP.new(token_uri.host, token_uri.port)
        http_access_token.use_ssl = true
        token_request = Net::HTTP::Post.new(token_uri.request_uri)
        token_request.set_form_data(
          {
            'grant_type' => @@grant_type, 
            'client_id' => @data_hash['aadClientId'], 
            'client_secret' => @data_hash['aadClientSecret'],
            'resource' => @@token_resource_url
            }
        )
        
        token_response = http_access_token.request(token_request)
        # Handle the case where the response is not 200 
        parsed_json = JSON.parse(token_response.body)
        @token_expiry_time = Time.now + 59*60 # set the expiry time to be ~one hour from current time
        @cached_access_token = parsed_json['access_token']
      end
      @cached_access_token
    end 

    def write_status_file(success, message)
      fn = '/var/opt/microsoft/omsagent/log/MDMIngestion.status'
      status = '{ "operation": "MDMIngestion", "success": "%s", "message": "%s" }' % [success, message]
      begin
        File.open(fn,'w') { |file| file.write(status) }
      rescue => e
        @log.debug "Error:'#{e}'"
        ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
      end
    end

    # This method is called when an event reaches to Fluentd.
    # Convert the event to a raw string.
    def format(tag, time, record)
      if record != {}
        @log.trace "Buffering #{tag}"
        return [tag, record].to_msgpack
      else
        return ""
      end
    end

    # This method is called every flush interval. Send the buffer chunk to MDM. 
    # 'chunk' is a buffer chunk that includes multiple formatted records
    def write(chunk)
      begin
        if (!@first_post_attempt_made || (Time.now > @last_post_attempt_time + retry_mdm_post_wait_minutes*60)) && @can_send_data_to_mdm
          post_body = []
          chunk.msgpack_each {|(tag, record)|
            post_body.push(record.to_json)
          }
          send_to_mdm post_body
        else
          if !@can_send_data_to_mdm
            @log.info "Cannot send data to MDM since all required conditions were not met"
          else
            @log.info "Last Failed POST attempt to MDM was made #{((Time.now - @last_post_attempt_time)/60).round(1)} min ago. This is less than the current retry threshold of #{@retry_mdm_post_wait_minutes} min. NO-OP"
          end
        end
      rescue Exception => e
        @log.info "Exception when writing to MDM: #{e}"
        raise e
      end
    end

    def send_to_mdm(post_body) 
      begin
        access_token = get_access_token
        request = Net::HTTP::Post.new(@post_request_uri.request_uri)
        request['Content-Type'] = "application/x-ndjson"
        request['Authorization'] = "Bearer #{access_token}"
        request.body = post_body.join("\n")
        response = @http_client.request(request)
        response.value # this throws for non 200 HTTP response code
        @log.info "HTTP Post Response Code : #{response.code}"
        ApplicationInsightsUtility.sendCustomEvent("AKSCustomMetricsMDMSendSuccessful", {})
      rescue Net::HTTPServerException => e
        @log.info "Failed to Post Metrics to MDM : #{e} Response: #{response}"
        @log.debug_backtrace(e.backtrace)
        if !response.code.empty? && response.code == 403.to_s
          @log.info "Response Code #{response.code} Updating @last_post_attempt_time"
          @last_post_attempt_time = Time.now
          @first_post_attempt_made = true
          ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
          # Not raising exception, as that will cause retries to happen
        elsif !response.code.empty? && response.code.start_with?('4')
          # Log 400 errors and continue
          @log.info "Non-retryable HTTPServerException when POSTing Metrics to MDM #{e} Response: #{response}"
        else 
          # raise if the response code is non-400
          @log.info "HTTPServerException when POSTing Metrics to MDM #{e} Response: #{response}"
          raise e
        end
      rescue Errno::ETIMEDOUT => e
        @log.info "Timed out when POSTing Metrics to MDM : #{e} Response: #{response}"
        @log.debug_backtrace(e.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
        raise e
      rescue Exception => e
        @log.info "Exception POSTing Metrics to MDM : #{e} Response: #{response}"
        @log.debug_backtrace(e.backtrace)
        ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
        raise e
      end
    end
  private

    class ChunkErrorHandler
      include Configurable
      include PluginId
      include PluginLoggerMixin

      SecondaryName = "__ChunkErrorHandler__"

      Plugin.register_output(SecondaryName, self)

      def initialize
        @router = nil
      end

      def secondary_init(primary)
        @error_handlers = create_error_handlers @router
      end

      def start
        # NOP
      end

      def shutdown
        # NOP
      end

      def router=(r)
        @router = r
      end

      def write(chunk)
        chunk.msgpack_each {|(tag, record)|
          @error_handlers[tag].emit(record)
        }
      end
   
    private

      def create_error_handlers(router)
        nop_handler = NopErrorHandler.new
        Hash.new() { |hash, tag|
          etag = OMS::Common.create_error_tag tag
          hash[tag] = router.match?(etag) ?
                      ErrorHandler.new(router, etag) :
                      nop_handler
        }
      end

      class ErrorHandler
        def initialize(router, etag)
          @router = router
          @etag = etag
        end

        def emit(record)
          @router.emit(@etag, Fluent::Engine.now, record)
        end
      end

      class NopErrorHandler
        def emit(record)
          # NOP
        end
      end

    end

  end # class OutputMDM

end # module Fluent

