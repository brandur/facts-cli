class RestHelper
  #FactsUri = 'http://facts.brandur.org'
  FactsUri = 'http://localhost:3000'

  class << self
    def delete(relative_uri)
      parse(RestClient.delete("#{FactsUri}#{relative_uri}"))
    end

    def get(relative_uri, params = {})
      parse(RestClient.get("#{FactsUri}#{relative_uri}", :params => params))
    end

    def parse(json)
      begin
        JSON.parse(json)
      rescue JSON::ParserError
        false
      end
    end

    def post(relative_uri, params = {})
      parse(RestClient.post("#{FactsUri}#{relative_uri}", params))
    end

    def put(relative_uri, params = {})
      parse(RestClient.put("#{FactsUri}#{relative_uri}", params))
    end
  end
end
