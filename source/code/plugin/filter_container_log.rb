# frozen_string_literal: true

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
      record['Computer'] =  @hostname
      wrapper = {
                 "DataType"=>"CONTAINER_LOG_BLOB",
                 "IPName"=>"Containers",
                 "DataItems"=>[record.each{|k,v| record[k]=v}]
      }
      wrapper
    end
  end
end
