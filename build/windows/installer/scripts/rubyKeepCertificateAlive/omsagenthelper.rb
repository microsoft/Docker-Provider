# frozen_string_literal: true
# Why do the above though win windows? Check in Perf testing

module OMS
  class OnboardingHelper
    require "openssl"
    require "net/http"
    require "base64"
    require "digest"
    require "fileutils"

    require_relative "AgentTopologyRequestHandler"
    require_relative "omscommon"

    @@workspace_id = ""
    @@domain = ""
    @@certificate_update_endpoint = ""
    @@cert_path = ""
    @@key_path = ""
    @@agent_guid = ""
    @@proxy_endpoint = {}

    # Initialize onboarding helper, If these values do not exist fail horribly
    def initialize(workspace_id, domain, agent_guid)
      # DO nil check for parameters here
      @workspace_id = workspace_id
      @domain = domain
      @certificate_update_endpoint = "https://" + workspace_id + "." + domain + "/ConfigurationService.Svc/RenewCertificate"
      @cert_path = ENV["CI_CERT_LOCATION"]
      @key_path = ENV["CI_KEY_LOCATION"]
      proxy_conf = ENV["PROXY"]
      if !proxy_conf.nil? && !proxy_conf.empty?
        @proxy_endpoint = proxy_conf
      else
        @proxy_endpoint = {}
      end
      @agent_guid = agent_guid #let's get this from certificate : more reliable?
    end

    # Return the certificate text as a single formatted string
    def get_cert_server(cert_path)
      cert_server = ""
      cert_file_contents = File.readlines(cert_path)
      for i in 1..(cert_file_contents.length - 2) # skip first and last line in file
        line = cert_file_contents[i]
        cert_server.concat(line[0..-2])
        if i < (cert_file_contents.length - 2)
          cert_server.concat(" ")
        end
      end
      return cert_server
    end

    # Generate the request body
    def generate_request_body
      begin
        agentTopologyRequestHandler = AgentTopologyRequestHandler.new()
        request_body_xml = agentTopologyRequestHandler.handle_request(@agent_guid, get_cert_server(@cert_path))
      rescue => e
        puts "Error when generating request body for OMS agent management service topology request: #{e.message}"
      end

      return request_body_xml
    end

    def get_user_agent
      # We need to replace akswindowslog with a version number. (not necessary but it is cleaner and the right way to do it)
      return "MicrosoftMonitoringAgent/akswindowslog"
    end

    def generate_request_headers()
      headers = {}
      req_date = Time.now.utc.strftime("%Y-%m-%dT%T.%N%:z")
      headers[CaseSensitiveString.new("x-ms-Date")] = req_date
      headers["User-Agent"] = get_user_agent
      headers[CaseSensitiveString.new("Accept-Language")] = "en-US"
      return headers
    end

    # create an HTTP object which uses HTTPS
    def create_secure_http(uri)
      proxy = {}
      if !@proxy_endpoint.nil? && !@proxy_endpoint.empty?
        proxy = parseProxyConfiguration(@proxy_endpoint)
      end

      if proxy.nil? || proxy.empty?
        http = Net::HTTP.new(uri.host, uri.port)
      else
        http = Net::HTTP.new(uri.host, uri.port,
                             proxy[:addr], proxy[:port], proxy[:user], proxy[:pass])
      end
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = 30
      return http
    end # create_secure_http

    # Return a POST request with the specified headers, URI, and body, and an
    #     HTTP to execute that request
    def form_post_request_and_http(headers, uri_string, body, cert, key)
      uri = URI.parse(uri_string)
      req = Net::HTTP::Post.new(uri.request_uri, headers)
      req.body = body
      http = create_secure_http(uri)
      http.cert = cert
      http.key = key
      return req, http
    end

    # Create file which the livenessprobe is checking for to restart the container
    def renew_certs
      filename = "C:\\etc\\omsagentwindows\\renewcertificate.txt"
      File.open(filename, "w") { |f| f.write("Please renew the certificate") }
      if File.file?(filename) == true
        return OMS::ERROR_EXECUTING_RENEW_CERTS_COMMAND
      end
    end

    # Updates the CERTIFICATE_UPDATE_ENDPOINT variable and renews certificate if requested
    def apply_certificate_update_endpoint(server_resp)
      update_attr = ""
      cert_update_endpoint = ""
      # Extract the certificate update endpoint from the server response
      endpoint_tag_regex = /\<CertificateUpdateEndpoint.*updateCertificate=\"(?<update_cert>(true|false))\".*(?<cert_update_endpoint>https.*RenewCertificate).*CertificateUpdateEndpoint\>/
      endpoint_tag_regex.match(server_resp) { |match|
        cert_update_endpoint = match["cert_update_endpoint"]
        update_attr = match["update_cert"]
      }
      if cert_update_endpoint.empty?
        puts "Could not extract the update certificate endpoint."
        return OMS::MISSING_CERT_UPDATE_ENDPOINT
      elsif update_attr.empty?
        puts "Could not find the updateCertificate tag in OMS Agent management service telemetry response"
        return OMS::ERROR_EXTRACTING_ATTRIBUTES
      end

      # Check in the response if the certs should be renewed
      if update_attr == "true"
        puts "Update certificate attribute is set to true"
        renew_certs_ret = renew_certs
        if renew_certs_ret != 0
          return renew_certs_ret
        end
      else
        puts "no update needed"
      end

      return cert_update_endpoint
    end

    def register_certs()
      puts "Register certs starts..."

      request_headers = generate_request_headers()
      request_body_xml = generate_request_body()

      # Form POST request and HTTP
      req, http = form_post_request_and_http(request_headers, "https://#{@workspace_id}.oms.#{@domain}/" \
      "AgentService.svc/AgentTopologyRequest",
                                             request_body_xml,
                                             OpenSSL::X509::Certificate.new(File.open(@cert_path)),
                                             OpenSSL::PKey::RSA.new(File.open(@key_path)))
      File.open("C:\\body_onboard.xml", "w") { |file| file.write(req.body) }
      # Submit request
      begin
        res = nil
        res = http.start { |http_each| http.request(req) }
      rescue => e
        puts "Error sending the topology request to OMS agent management service: #{e.message}"
      end

      if !res.nil?
        puts "OMS agent management service topology request response code: #{res.code}"
        puts "#{res.body}"
        if res.code == "200"
          puts "Request succeded, now checking for update"
          cert_apply_res = apply_certificate_update_endpoint(res.body)
          if cert_apply_res.class != String
            return cert_apply_res
          else
            puts "OMS agent management service topology request success"
            return 0
          end
        else
          puts "Error sending OMS agent management service topology request . HTTP code #{res.code}"
          puts "Body -> #{res.body}"
          return OMS::HTTP_NON_200
        end
      else
        puts "Error sending OMS agent management service topology request . No HTTP code"
        return OMS::ERROR_SENDING_HTTP
      end
    end

    # parse proxy configuration
    def parseProxyConfiguration(proxy_conf_str)
      # Remove the http(s) protocol
      proxy_conf_str = proxy_conf_str.gsub(/^(https?:\/\/)?/, "")

      # Check for unsupported protocol
      if proxy_conf_str[/^[a-z]+:\/\//]
        return nil
      end

      re = /^(?:(?<user>[^:]+):(?<pass>[^@]+)@)?(?<addr>[^:@]+)(?::(?<port>\d+))?$/
      matches = re.match(proxy_conf_str)
      if matches.nil? or matches[:addr].nil?
        return nil
      end
      # Convert nammed matches to a hash
      Hash[ matches.names.map{ |name| name.to_sym}.zip( matches.captures ) ]
    end

  end
end

# Boilerplate syntax for ruby
if __FILE__ == $0
  ret_code = 0
  maintenance = OMS::OnboardingHelper.new(
    ENV["WSID"],
    ENV["DOMAIN"],
    ENV["CI_AGENT_GUID"]
  )
  ret_code = maintenance.register_certs()
  puts "Return code is #{ret_code} : (0 == Good, anything else == bad)"
  exit ret_code
end
