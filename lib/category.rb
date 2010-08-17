require 'lib/restful_record'

class Category
  include RestfulRecord

  attr_accessor :category_id, :name, :slug
  resource_named :categories

  def self.search(query, options = {})
    RestHelper.get("/#{resource_name}/search.json", :query => query, :include_facts => options[:include_facts]).collect{ |r| new(r) }
  end

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
