require 'lib/restful_record'

class Fact
  include RestfulRecord

  attr_accessor :category_id, :content
  resource_named :facts

  def category
    @category
  end

  def category=(category)
    @category = Category.new(category)
  end

  def to_json
    x = { :fact => { :id => @id, :category_id => @category_id, :content => @content } }
    puts "to_json = #{x.inspect}"
    x
  end
end
