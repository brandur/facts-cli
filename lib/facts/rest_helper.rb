require 'json'
require 'rest_client'

module Facts
  class RestHelper
    class << self
      def delete(relative_uri)
        rescue_errors do
          parse(get_resource(relative_uri).delete())
        end
      end

      def get(relative_uri, params = {})
        rescue_errors do
          parse(get_resource(relative_uri).get(:params => params))
        end
      end

      def get_resource(relative_uri)
        Facts.ui.debug "resource = #{Facts.config.uri}#{relative_uri}"
        if Facts.config.user
          Facts.ui.debug "user = #{Facts.config.user}"
          RestClient::Resource.new "#{Facts.config.uri}#{relative_uri}", Facts.config.user, Facts.config.password
        else
          RestClient::Resource.new "#{Facts.config.uri}#{relative_uri}"
        end
      end

      def parse(json)
        unless json.nil? || json.strip.empty?
          Facts.ui.debug "response = #{json}"
          begin
            JSON.parse(json)
          rescue JSON::ParserError
            raise JsonParseError, "failed to parse response JSON"
          end
        else
          Facts.ui.debug "response = <empty>"
        end
      end

      def post(relative_uri, params = {})
        Facts.ui.debug "post = #{params.inspect}"
        rescue_errors do
          parse(get_resource(relative_uri).post(params))
        end
      end

      def put(relative_uri, params = {})
        Facts.ui.debug "put = #{params.inspect}"
        rescue_errors do
          parse(get_resource(relative_uri).put(params))
        end
      end

      private

      def rescue_errors
        begin
          yield
        rescue RestClient::InternalServerError
          raise InternalServerError, "500 internal server error from host"
        rescue RestClient::Unauthorized
          raise RestClient::Unauthorized, "401 unauthorized (check username/pass in .factsrc)"
        rescue RestClient::UnprocessableEntity
          raise UnprocessableEntityError, "422 unprocessable entry (validation error? duplicate?)"
        end
      end
    end
  end
end
