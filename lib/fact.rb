require 'lib/restful_record'

class Fact
  include RestfulRecord

  attr_accessor :category_id, :content
  resource_named :facts

  def to_json
    { :fact => { :id => @id, :category_id => @category_id, :content => @content } }
  end
end
