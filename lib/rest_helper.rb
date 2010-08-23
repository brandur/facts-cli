class RestHelper
  #FactsUri = 'http://facts.brandur.org'
  FactsUri = 'http://localhost:3000'

  class << self
    def delete(relative_uri)
      parse(get_resource(relative_uri).delete())
    end

    def get(relative_uri, params = {})
      parse(get_resource(relative_uri).get(:params => params))
    end

    def get_resource(relative_uri)
      if defined?(@@user)
        RestClient::Resource.new "#{FactsUri}#{relative_uri}", @@user, @@password
      else
        RestClient::Resource.new "#{FactsUri}#{relative_uri}"
      end
    end

    def parse(json)
      begin
        JSON.parse(json)
      rescue JSON::ParserError
        false
      end
    end

    def password=(val)
      @@password = val
    end

    def post(relative_uri, params = {})
      parse(get_resource(relative_uri).post(params))
    end

    def put(relative_uri, params = {})
      parse(get_resource(relative_uri).put(params))
    end

    def user=(val)
      @@user = val
    end
  end
end
