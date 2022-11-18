# Copyright (c) Microsoft Corporation.  All rights reserved.
#!/usr/local/bin/ruby
# frozen_string_literal: true

class ProxyUtils
  class << self
    def getProxyConfiguration()
      amalogsproxy_secret_path = "/etc/ama-logs-secret/PROXY"
      if !File.exist?(amalogsproxy_secret_path)
        return {}
      end

      begin
        proxy_config = parseProxyConfiguration(File.read(amalogsproxy_secret_path))
      rescue SystemCallError # Error::ENOENT
        return {}
      end

      if proxy_config.nil?
        $log.warn("Failed to parse the proxy configuration in '#{amalogsproxy_secret_path}'")
        return {}
      end

      return proxy_config
    end

    def parseProxyConfiguration(proxy_conf_str)
      if proxy_conf_str.empty?
        return nil
      end
      # Remove trailing / if the proxy endpoint has
      if proxy_conf_str.end_with?("/")
        proxy_conf_str = proxy_conf_str.chop
      end
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
      Hash[matches.names.map { |name| name.to_sym }.zip(matches.captures)]
    end

    def isProxyCACertConfigured()
      isProxyCACertExist = false
      begin
        proxy_cert_path = "/etc/ama-logs-secret/PROXYCERT.crt"
        if File.exist?(proxy_cert_path)
          isProxyCACertExist = true
        end
      rescue => error
        $log.warn("Failed to check the existence of Proxy CA cert '#{proxy_cert_path}'")
      end
      return isProxyCACertExist
    end
  end
end
