require 'active_support/log_subscriber'

class BobRoss::LogSubscriber < ActiveSupport::LogSubscriber
    INTERNAL_PARAMS = %w(controller action format _method only_path)

    def start_processing(event)
      info "Processing by BobRoss"
    end

    def process(event)
      info do
        payload = event.payload
        additions = []
        status = payload[:status]

        if status.nil? && payload[:exception].present?
          exception_class_name = payload[:exception].first
          status = ActionDispatch::ExceptionWrapper.status_code_for_exception(exception_class_name)
        end

        # additions << "Allocations: #{event.allocations}"

        message = +"Completed #{status} #{Rack::Utils::HTTP_STATUS_CODES[status]} in #{event.duration.round}ms"
        message << " (#{additions.join(" | ")})" unless additions.empty?
        message << "\n\n" if defined?(Rails.env) && Rails.env.development?

        message
      end
    end

    def invalid_hmac(event)
      info do
        payload = event.payload
        valid_hmacs = payload[:valid_hmacs].map{|h| "\"#{h}\""}.to_sentence(two_words_connector: ' or ', last_word_connector: ", or ")
        "  HMAC Invalid \"#{payload[:hmac]}\", expected #{valid_hmacs}"
      end
    end

    def expired(event)
      info { "  URL Expired at #{event.payload[:expired_at]}" }
    end
    
    def unsupported_media_type(event)
      info { "  Could not find support media type (accepts: #{event.payload[:accept]})" }
    end

    def rendered(event)
      info { "  Rendered #{event.payload[:transformations].inspect} (#{event.duration.round(1)}ms) [cache #{event.payload[:cache] ? 'hit' : 'miss'}]" }
    end
    
    # def send_file(event)
    #   info { "Sent file #{event.payload[:path]} (#{event.duration.round(1)}ms)" }
    # end

    # def send_data(event)
    #   info { "Sent data #{event.payload[:filename]} (#{event.duration.round(1)}ms)" }
    # end

    def logger
      BobRoss.logger
    end
end

BobRoss::LogSubscriber.attach_to :bob_ross