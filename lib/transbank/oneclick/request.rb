require 'open3'

module Transbank
  module Oneclick

    class InvalidTransbankCallError < SecurityError
    end

    class Request
      attr_accessor :xml, :client, :action, :rescue_exceptions, :validation_script

      def initialize(action, params = {}, opt = {})
        opt = {
          rescue_exceptions: Transbank::Oneclick.configuration.rescue_exceptions,
          http_options: {}
        }.merge(opt)

        self.validation_script = Transbank::Oneclick.configuration.validation_script
        self.action = action
        self.rescue_exceptions = opt[:rescue_exceptions]
        self.xml = Document.new(action, params)
        self.client = Client.new opt.delete(:http_options)
      end

      def response
        @Response ||= begin
          c = client.post(xml.canonicalize)

          if(validation_script) # Validate if script present
            if(validate_response(c.body))
              Response.new c, action
            else
              raise InvalidTransbankCallError, "Invalid Transbank Response"
            end
          else
            puts "[WARNING] Non validated response!"
            Response.new c, action
          end

        rescue match_class(rescue_exceptions) => error
          ExceptionResponse.new error, action
        end
      end

      private
        def match_class(exceptions)
          m = Module.new
          (class << m; self; end).instance_eval do
            define_method(:===) do |error|
              (exceptions || []).include? error.class
            end
          end
          m
        end

        def validate_response(body)
          is_valid = false

          Open3.popen2(validation_script) do |i, o, t|
            i.print body.to_s
            i.close
            is_valid = o.gets == 'valid'
          end

          is_valid
        end
    end
  end
end