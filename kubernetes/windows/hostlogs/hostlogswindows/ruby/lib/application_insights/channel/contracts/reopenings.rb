module ApplicationInsights::Channel::Contracts
    class ExceptionData
        def handled_at
            @properties["handledAt"] if @properties
        end

        def handled_at=(handled_at)
            if handled_at
                @properties ||= {}
                @properties["handledAt"] = handled_at
            end
        end
    end

    class RequestData
        def http_method
            @properties["httpMethod"] if @properties
        end

        def http_method=(http_method)
            if http_method
                @properties ||= {}
                @properties["httpMethod"] = http_method
            end
        end
    end
end