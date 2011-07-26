require 'facts/fact'
require 'facts/restful_record'

module Facts
  class Category
    include RestfulRecord

    attr_accessor :category_id, :name, :slug
    resource_named :categories

    def facts
      @facts
    end

    def facts=(facts)
      @facts = facts.collect{ |f| Fact.new(f) }
    end

    def to_json
      { :category => { :id => @id, :category_id => @category_id, :name => @name } }
    end
  end
end
