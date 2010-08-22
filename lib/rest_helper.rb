class RestHelper
  #FactsUri = 'http://facts.brandur.org'
  FactsUri = 'http://localhost:3000'

  class << self
    def delete(relative_uri, params = {})
      parse(RestClient.delete("#{FactsUri}#{relative_uri}", :params => make_params(params)))
    end

    def get(relative_uri, params = {})
      parse(RestClient.get("#{FactsUri}#{relative_uri}", :params => make_params(params)))
    end

    def login=(val)
      @@login = val
    end

    def make_params(params)
      if defined?(@@login)
        params.merge({ :login => @@login, :password => @@password })
      else
        params
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
      parse(RestClient.post("#{FactsUri}#{relative_uri}", make_params(params)))
    end

    def put(relative_uri, params = {})
      parse(RestClient.put("#{FactsUri}#{relative_uri}", make_params(params)))
    end
  end
end
