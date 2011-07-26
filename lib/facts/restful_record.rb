require 'facts/rest_helper'

module Facts
  module RestfulRecord
    attr_accessor :id

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def daily(options = {})
        RestHelper.get("/#{resource_name}/daily.json", options).collect { |r| new(r) }
      end

      def find(id)
        new(RestHelper.get("/#{resource_name}/#{id}.json"))
      end

      def resource_named(resource_name)
        module_eval "def self.resource_name; '#{resource_name}'; end"
        module_eval "def resource_name; '#{resource_name}'; end"
      end

      def search(query, options = {})
        options = options.merge(:query => query)
        RestHelper.get("/#{resource_name}/search.json", options).collect{ |r| new(r) }
      end

      def search_one(query, options = {})
        objs = search_one_or_more(query, options)

        # If we got back more than one, try to refine search with an exact match 
        # only
        objs = objs.find_all{ |o| o.id.to_s == query } if objs.count > 1
        raise ImpreciseQueryError, "more than one object match for query '#{query}'" if objs.count != 1
        objs[0]
      end

      def search_one_or_more(query, options = {})
        objs = search(query, options)
        raise ImpreciseQueryError, "no objects matched '#{query}'" if objs.count < 1
        objs
      end
    end

    def destroy
      RestHelper.delete("/#{resource_name}/#{id}.json")
    end

    def initialize(attributes)
      update_attributes(attributes) if attributes
    end

    def new_record?
      @id.nil?
    end

    def save
      if new_record?
        insert
      else
        update
      end
    end

    def update_attributes(attributes)
      # Unpack the attributes if necessary
      attributes = attributes[entity_name] if attributes[entity_name]
      attributes.each do |name, value|
        send(name.to_s + '=', value) if respond_to? name.to_s
      end
    end

    protected
    
    def entity_name
      # Class name without module path
      self.class.name.split('::').last.downcase
    end

    def insert
      update_attributes(RestHelper.post("/#{resource_name}.json", to_json))
    end

    def update
      RestHelper.put("/#{resource_name}/#{id}.json", to_json)
    end
  end
end
