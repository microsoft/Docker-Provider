module OMS

  MSDockerCImprovHostnameFilePath = '/var/opt/microsoft/docker-cimprov/state/containerhostname'
  IPV6_REGEX = '\h{4}:\h{4}:\h{4}:\h{4}:\h{4}:\h{4}:\h{4}:\h{4}'
  IPV4_Approximate_REGEX = '\d+\.\d+\.\d+\.\d+'

  class RetryRequestException < Exception
    # Throw this exception to tell the fluentd engine to retry and
    # inform the output plugin that it is indeed retryable
  end

  class Common
    require 'socket'        
    require_relative 'omslog'

    @@Hostname = nil
    @@HostnameFilePath = MSDockerCImprovHostnameFilePath


    class << self

      # Internal methods
      # (left public for easy testing, though protected may be better later)

      def clean_hostname_string(hnBuffer)
        return "" if hnBuffer.nil? # So give the rest of the program a string to deal with.
        hostname_buffer = hnBuffer.strip
        return hostname_buffer
      end

      def has_designated_hostnamefile?
        return false if @@HostnameFilePath.nil?
        return false unless @@HostnameFilePath =~ /\w/
        return false unless File.exist?(@@HostnameFilePath)
        return true
      end

      def is_dot_separated_string?(hnBuffer)
        return true if /[^.]+\.[^.]+/ =~ hnBuffer
        return false
      end

      def is_hostname_compliant?(hnBuffer)
        # RFC 2181:
        #   Size limit is 1 to 63 octets, so probably bytesize is appropriate method.
        return false if hnBuffer.nil?
        return false if /\./ =~ hnBuffer # Hostname by definition may not contain a dot.
        return false if /:/ =~ hnBuffer # Hostname by definition may not contain a colon.
        return false unless 1 <= hnBuffer.bytesize && hnBuffer.bytesize <= 63
        return true
      end

      def is_like_ipv4_string?(hnBuffer)
        return false unless /\A#{IPV4_Approximate_REGEX}\z/ =~ hnBuffer
        qwa = hnBuffer.split('.')
        return false unless qwa.length == 4
        return false if qwa[0].to_i == 0
        qwa.each do |quadwordstring|
            bi = quadwordstring.to_i
            # This may need more detail if 255 octets are sometimes allowed, but I don't think so.
            return false unless 0 <= bi and bi < 255
        end
        return true
      end

      def is_like_ipv6_string?(hnBuffer)
        return true if /\A#{IPV6_REGEX}\z/ =~ hnBuffer
        return false
      end

      def look_for_socket_class_host_address
        hostname_buffer = nil

        begin
          hostname_buffer = Socket.gethostname
        rescue => error
          OMS::Log.error_once("Unable to get the Host Name using socket facility: #{error}")
          return
        end
        @@Hostname = clean_hostname_string(hostname_buffer)

        return # Thwart accidental return to force correct use.
      end

      def look_in_designated_hostnamefile
        # Issue:
        #   When ama-logs runs inside a container, gethostname returns the hostname of the container (random name)
        #   not the actual machine hostname.
        #   One way to solve this problem is to set the container hostname same as machine name, but this is not
        #   possible when host-machine is a private VM inside a cluster.
        # Solution:
        #   Share/mount ‘/etc/hostname’ as '/var/opt/microsoft/ama-logs/state/containername' with container and
        #   ama-logs will read hostname from shared file.
        hostname_buffer = nil

        unless File.readable?(@@HostnameFilePath)
            OMS::Log.warn_once("File '#{@@HostnameFilePath}' exists but is not readable.")
            return
        end

        begin
          hostname_buffer = File.read(@@HostnameFilePath)
        rescue => error
          OMS::Log.warn_once("Unable to read the hostname from #{@@HostnameFilePath}: #{error}")
        end
        @@Hostname = clean_hostname_string(hostname_buffer)
        return # Thwart accidental return to force correct use.
      end

      def validate_hostname_equivalent(hnBuffer)
        # RFC 1123 and 2181
        # Note that for now we are limiting the earlier maximum of 63 for fqdn labels and thus
        # hostnames UNTIL we are assured azure will allow 255, as specified in RFC 1123, or
        # we are otherwise instructed.
        rfcl = "RFCs 1123, 2181 with hostname range of {1,63} octets for non-root item."
        return if is_hostname_compliant?(hnBuffer)
        return if is_like_ipv4_string?(hnBuffer) 
        return if is_like_ipv6_string?(hnBuffer)
        msg = "Hostname '#{hnBuffer}' not compliant (#{rfcl}).  Not IP Address Either."
        OMS::Log.warn_once(msg)
        raise NameError, msg
      end

      # End of Internal methods

      def get_hostname(ignoreOldValue = false)
        if not is_hostname_compliant?(@@Hostname) or ignoreOldValue then

            look_in_designated_hostnamefile         if has_designated_hostnamefile?

            look_for_socket_class_host_address  unless is_hostname_compliant?(@@Hostname)
        end

        begin
          validate_hostname_equivalent(@@Hostname)
        rescue => error
          OMS::Log.warn_once("Hostname '#{@@Hostname}' found, but did NOT validate as compliant.  #{error}.  Using anyway.")
        end
        return @@Hostname
      end
    end # Class methods
  end # class Common
end # module OMS
