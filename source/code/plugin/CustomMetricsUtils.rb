#!/usr/local/bin/ruby
# frozen_string_literal: true

class CustomMetricsUtils
    def initialize
    end

    class << self
        def check_custom_metrics_availability(custom_metric_regions)
            aks_region = ENV['AKS_REGION']
            aks_resource_id = ENV['AKS_RESOURCE_ID']
            if aks_region.to_s.empty? || aks_resource_id.to_s.empty?
                return false # This will also take care of AKS-Engine Scenario. AKS_REGION/AKS_RESOURCE_ID is not set for AKS-Engine. Only ACS_RESOURCE_NAME is set
            end
            
            custom_metrics_regions_arr = custom_metric_regions.split(',')
            custom_metrics_regions_hash = custom_metrics_regions_arr.map {|x| [x.downcase,true]}.to_h

            if custom_metrics_regions_hash.key?(aks_region.downcase)
                true
            else 
                false
            end
        end
    end
end