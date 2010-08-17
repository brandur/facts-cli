require 'lib/restful_record'

class Category
  include RestfulRecord

  attr_accessor :category_id, :name, :slug
  resource_named :categories

  def to_json
    { :category => { :id => @id, :category_id => @category_id, :name => @name } }
  end
end
