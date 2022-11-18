# frozen_string_literal: true
require "logger"
require "net/http"
require "net/https"
require "uri"
require "json"
require "base64"
require "time"
require_relative "KubernetesApiClient"
require_relative "ApplicationInsightsUtility"

class ArcK8sClusterIdentity
  # this arc k8s crd version  and arc k8s  uses corresponding version v1beta1 vs v1 based on the k8s version for apiextensions.k8s.io
  @@cluster_config_crd_api_version = "clusterconfig.azure.com/v1beta1"
  @@cluster_identity_resource_name = "container-insights-clusteridentityrequest"
  @@cluster_identity_resource_namespace = "azure-arc"
  @@cluster_identity_token_secret_namespace = "azure-arc"
  @@crd_resource_uri_template = "%{kube_api_server_url}/apis/%{cluster_config_crd_api_version}/namespaces/%{cluster_identity_resource_namespace}/azureclusteridentityrequests/%{cluster_identity_resource_name}"
  @@secret_resource_uri_template = "%{kube_api_server_url}/api/v1/namespaces/%{cluster_identity_token_secret_namespace}/secrets/%{token_secret_name}"
  @@azure_monitor_custom_metrics_audience = "https://monitoring.azure.com/"
  @@cluster_identity_request_kind = "AzureClusterIdentityRequest"

  def initialize
    @os_type = ENV["OS_TYPE"]
    if !@os_type.nil? && !@os_type.empty? && @os_type.strip.casecmp("windows") == 0
      @LogPath = "/etc/amalogswindows/arc_k8s_cluster_identity.log"
    else
      @LogPath = "/var/opt/microsoft/docker-cimprov/log/arc_k8s_cluster_identity.log"
    end
    @log = Logger.new(@LogPath, 1, 5000000)
    @log.info "initialize start @ #{Time.now.utc.iso8601}"
    @token_expiry_time = Time.now
    @cached_access_token = String.new
    @isLastTokenRenewalUpdatePending = false
    @token_file_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    @cert_file_path = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    @kube_api_server_url = KubernetesApiClient.getKubeAPIServerUrl
    if @kube_api_server_url.nil?
      @log.warn "got api server url nil from KubernetesApiClient.getKubeAPIServerUrl @ #{Time.now.utc.iso8601}"
    end
    @http_client = get_http_client
    @service_account_token = get_service_account_token
    @extensionName = ENV["ARC_K8S_EXTENSION_NAME"]
    @log.info "extension name:#{@extensionName} @ #{Time.now.utc.iso8601}"
    @log.info "initialize complete @ #{Time.now.utc.iso8601}"
  end

  def get_cluster_identity_token()
    begin
      # get the cluster msi identity token either if its empty or near expiry. Token is valid 24 hrs.
      if @cached_access_token.to_s.empty? || (Time.now + 60 * 60 > @token_expiry_time) # Refresh token 1 hr from expiration
        # renew the token if its near expiry
        if !@cached_access_token.to_s.empty? && (Time.now + 60 * 60 > @token_expiry_time)
          if !@isLastTokenRenewalUpdatePending
            @log.info "token expiry - @ #{@token_expiry_time}"
            @log.info "renewing the token since token has near expiry @ #{Time.now.utc.iso8601}"
            renew_near_expiry_token
            # sleep 60 seconds to get the renewed token  available
            sleep 60
            @isLastTokenRenewalUpdatePending = true
          else
            @log.warn "last token renewal update still pending @ #{Time.now.utc.iso8601}"
          end
        end
        @log.info "get token reference from crd @ #{Time.now.utc.iso8601}"
        tokenReference = get_token_reference_from_crd
        if !tokenReference.nil? && !tokenReference.empty?
          @token_expiry_time = Time.parse(tokenReference["expirationTime"])
          token_secret_name = tokenReference["secretName"]
          token_secret_data_name = tokenReference["dataName"]
          # get the token from secret
          @log.info "get token from secret @ #{Time.now.utc.iso8601}"
          token = get_token_from_secret(token_secret_name, token_secret_data_name)
          if !token.nil?
            @cached_access_token = token
            @isLastTokenRenewalUpdatePending = false
          else
            @log.warn "got token nil from secret: #{@token_secret_name}"
          end
        else
          @log.warn "got token reference either nil or empty"
        end
      end
    rescue => err
      @log.warn "get_cluster_identity_token failed: #{err}"
      ApplicationInsightsUtility.sendExceptionTelemetry(err, { "FeatureArea" => "MDM" })
    end
    return @cached_access_token
  end

  private

  def get_token_from_secret(token_secret_name, token_secret_data_name)
    token = nil
    begin
      secret_request_uri = @@secret_resource_uri_template % {
        kube_api_server_url: @kube_api_server_url,
        cluster_identity_token_secret_namespace: @@cluster_identity_token_secret_namespace,
        token_secret_name: token_secret_name,
      }
      get_request = Net::HTTP::Get.new(secret_request_uri)
      get_request["Authorization"] = "Bearer #{@service_account_token}"
      @log.info "Making GET request to #{secret_request_uri} @ #{Time.now.utc.iso8601}"
      get_response = @http_client.request(get_request)
      @log.info "Got response of #{get_response.code} for #{secret_request_uri} @ #{Time.now.utc.iso8601}"
      if get_response.code.to_i == 200
        token_secret = JSON.parse(get_response.body)["data"]
        cluster_identity_token = token_secret[token_secret_data_name]
        token = Base64.decode64(cluster_identity_token)
      end
    rescue => err
      @log.warn "get_token_from_secret API call failed: #{err}"
      ApplicationInsightsUtility.sendExceptionTelemetry(err, { "FeatureArea" => "MDM" })
    end
    return token
  end

  private

  def get_token_reference_from_crd()
    tokenReference = {}
    begin
      crd_request_uri = @@crd_resource_uri_template % {
        kube_api_server_url: @kube_api_server_url,
        cluster_config_crd_api_version: @@cluster_config_crd_api_version,
        cluster_identity_resource_namespace: @@cluster_identity_resource_namespace,
        cluster_identity_resource_name: @@cluster_identity_resource_name,
      }
      get_request = Net::HTTP::Get.new(crd_request_uri)
      get_request["Authorization"] = "Bearer #{@service_account_token}"
      @log.info "Making GET request to #{crd_request_uri} @ #{Time.now.utc.iso8601}"
      get_response = @http_client.request(get_request)
      @log.info "Got response of #{get_response.code} for #{crd_request_uri} @ #{Time.now.utc.iso8601}"
      if get_response.code.to_i == 200
        status = JSON.parse(get_response.body)["status"]
        tokenReference["expirationTime"] = status["expirationTime"]
        tokenReference["secretName"] = status["tokenReference"]["secretName"]
        tokenReference["dataName"] = status["tokenReference"]["dataName"]
      elsif get_response.code.to_i == 404 # this might happen if the crd resource deleted by user accidently
        @log.info "since crd resource doesnt exist hence creating crd resource : #{@@cluster_identity_resource_name} @ #{Time.now.utc.iso8601}"
        crd_request_body = get_crd_request_body
        crd_request_body_json = crd_request_body.to_json
        create_request = Net::HTTP::Post.new(crd_request_uri)
        create_request["Content-Type"] = "application/json"
        create_request["Authorization"] = "Bearer #{@service_account_token}"
        create_request.body = crd_request_body_json
        create_response = @http_client.request(create_request)
        @log.info "Got response of #{create_response.code} for POST #{crd_request_uri} @ #{Time.now.utc.iso8601}"
      end
    rescue => err
      @log.warn "get_token_reference_from_crd call failed: #{err}"
      ApplicationInsightsUtility.sendExceptionTelemetry(err, { "FeatureArea" => "MDM" })
    end
    return tokenReference
  end

  private

  def renew_near_expiry_token()
    begin
      crd_request_uri = @@crd_resource_uri_template % {
        kube_api_server_url: @kube_api_server_url,
        cluster_config_crd_api_version: @@cluster_config_crd_api_version,
        cluster_identity_resource_namespace: @@cluster_identity_resource_namespace,
        cluster_identity_resource_name: @@cluster_identity_resource_name,
      }
      update_crd_request_body = { 'status': { 'expirationTime': "" } }
      update_crd_request_body_json = update_crd_request_body.to_json
      update_crd_request_uri = crd_request_uri + "/status"
      update_request = Net::HTTP::Patch.new(update_crd_request_uri)
      update_request["Content-Type"] = "application/merge-patch+json"
      update_request["Authorization"] = "Bearer #{@service_account_token}"
      update_request.body = update_crd_request_body_json
      update_response = @http_client.request(update_request)
      @log.info "Got response of #{update_response.code} for PATCH #{update_crd_request_uri} @ #{Time.now.utc.iso8601}"
      if update_response.code.to_i == 404
        @log.info "since crd resource doesnt exist hence creating crd resource : #{@@cluster_identity_resource_name} @ #{Time.now.utc.iso8601}"
        create_request = Net::HTTP::Post.new(crd_request_uri)
        create_request["Content-Type"] = "application/json"
        create_request["Authorization"] = "Bearer #{@service_account_token}"
        create_crd_request_body = get_crd_request_body
        create_crd_request_body_json = create_crd_request_body.to_json
        create_request.body = create_crd_request_body_json
        create_response = @http_client.request(create_request)
        @log.info "Got response of #{create_response.code} for POST #{crd_request_uri} @ #{Time.now.utc.iso8601}"
      end
    rescue => err
      @log.warn "renew_near_expiry_token call failed: #{err}"
      ApplicationInsightsUtility.sendExceptionTelemetry(err, { "FeatureArea" => "MDM" })
    end
  end

  private

  def get_service_account_token()
    begin
      if File.exist?(@token_file_path) && File.readable?(@token_file_path)
        token_str = File.read(@token_file_path).strip
        return token_str
      else
        @log.warn "Unable to read token string from #{@token_file_path}"
        return nil
      end
    rescue => err
      @log.warn "get_service_account_token call failed: #{err}"
      ApplicationInsightsUtility.sendExceptionTelemetry(err, { "FeatureArea" => "MDM" })
    end
  end

  private

  def get_http_client()
    begin
      base_api_server_url = URI.parse(@kube_api_server_url)
      http = Net::HTTP.new(base_api_server_url.host, base_api_server_url.port)
      http.use_ssl = true
      if !File.exist?(@cert_file_path)
        raise "#{@cert_file_path} doesnt exist"
      else
        http.ca_file = @cert_file_path
      end
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      return http
    rescue => err
      @log.warn "Unable to create http client #{err}"
      ApplicationInsightsUtility.sendExceptionTelemetry(err, { "FeatureArea" => "MDM" })
    end
    return nil
  end

  private

  def get_crd_request_body
    body = {}
    body["apiVersion"] = @@cluster_config_crd_api_version
    body["kind"] = @@cluster_identity_request_kind
    body["metadata"] = {}
    body["metadata"]["name"] = @@cluster_identity_resource_name
    body["metadata"]["namespace"] = @@cluster_identity_resource_namespace
    body["spec"] = {}
    body["spec"]["audience"] = @@azure_monitor_custom_metrics_audience
    if !@extensionName.nil? && !@extensionName.empty?
      body["spec"]["resourceId"] = @extensionName
    end
    return body
  end
end
