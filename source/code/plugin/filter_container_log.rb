require 'fluent/filter'

module Fluent
  require 'logger'
  class PassThruFilter < Filter
    Fluent::Plugin.register_filter('filter_container_log', self)

    def configure(conf)
      super
    end

    def start
      super
      @hostname = OMS::Common.get_hostname or "Unknown host"
    end

    def shutdown
      super
    end
    
    def filter(tag, time, record)
      begin
        #Try to force utf-8 encoding on the string so that all characters can flow through to
        record['LogEntry'].force_encoding('UTF-8')
      rescue
        $log.error "Failed to convert record['LogEntry'] : '#{record['LogEntry']}' to UTF-8 using force_encoding."
        $log.error "Current string encoding for record['LogEntry'] is #{record['LogEntry'].encoding}"
      end
      
      record['Computer'] =  @hostname
      record['LogEntry'] = "#{record['TimeGeneratedByLog']} #{record['LogEntry']}"
      wrapper = {
                 "DataType"=>"CONTAINER_LOG_BLOB",
                 "IPName"=>"Containers",
                 "DataItems"=>[record.each{|k,v| record[k]=v}]
      }
      wrapper
    end
  end
end
