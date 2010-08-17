require 'json'
require 'optparse'
require 'ostruct'
require 'rdoc/usage'
require 'rest_client'

require 'lib/category'
require 'lib/fact'
require 'lib/restful_record'

class FactsClient
  Version = '0.1'

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin
    @options = OpenStruct.new
  end

  def run
    begin
      if arguments_parsed? && arguments_valid?
        if @options.query && @options.category
          query_categories
        elsif @options.query && @options.fact
          query_facts
        elsif @options.new && @options.category
          new_categories
        elsif @options.new && @options.fact
          new_facts
        elsif @options.edit && @options.category
          edit_category
        elsif @options.edit && @options.fact
          edit_fact
        elsif @options.move && @options.category
          move_categories
        elsif @options.move && @options.fact
          move_facts
        elsif @options.destroy && @options.category
          destroy_categories
        elsif @options.destroy && @options.fact
          destroy_facts
        end
      else
        #output_help
      end
    rescue RestfulRecord::ImpreciseQueryError, NoEditorError
      $stderr.puts "#{$!}"
    rescue NoEditorChangeError
      puts "#{$!}"
    end
  end

  private

  def arguments_parsed?
    opts = OptionParser.new
    opts.on('-c', '--category')    { @options.category = true }
    opts.on('-d', '--destroy')     { @options.destroy = true }
    opts.on('-e', '--edit')        { @options.edit = true }
    opts.on('-f', '--fact')        { @options.fact = true }
    opts.on('-h', '--help')        { output_help }
    opts.on('-m', '--move')        { @options.move = true }
    opts.on('-n', '--new')         { @options.new = true }
    opts.on('-p', '--parent')      { @options.parent = true }
    opts.on('-q', '--query')       { @options.query = true }
    opts.on('-V', '--verbose')     { @options.verbose = true }
    opts.on('-v', '--version')     { output_version ; exit 0 }

    opts.parse!(@arguments) rescue return false
    true
  end

  def arguments_valid?
    if !@options.query && !@options.new && !@options.edit && !@options.move && !@options.destroy
      $stderr.puts 'An action must be specificied (e.g. query, new, ..)'
      false
    elsif !@options.category && !@options.fact
      $stderr.puts 'A mode must be specified (e.g. category or fact)'
      false
    elsif @options.query && @arguments.count > 1
      $stderr.puts 'Query only supports a single argument'
      false
    elsif @options.new && @arguments.count < 1 && (@options.category && @options.parent || @options.fact)
      $stderr.puts 'New action must have at least one argument'
      false
    elsif @options.edit && @arguments.count != 1 && @arguments.count != 2
      $stderr.puts 'Edit takes exactly one or two arguments'
      false
    elsif @options.move && @arguments.count < 2
      $stderr.puts 'Move action must have at least two arguments'
      false
    elsif @options.destroy && @arguments.count < 1
      $stderr.puts 'Destroy action must have at least one argument'
      false
    else
      true
    end
  end

  def destroy_categories
    @arguments.each do |c|
      category = Category.search_one(c)
      category.destroy
    end
    puts 'OK'
  end

  def destroy_facts
    @arguments.each do |f|
      fact = Fact.search_one(f)
      fact.destroy
    end
    puts 'OK'
  end

  def edit_category
    category = Category.search_one(@arguments.first)
    if @arguments.count == 1
      category.name = edit_in_temp_file(category.name)
    else
      category.name = @arguments.last
    end
    category.save
    puts 'OK'
  end

  def edit_in_temp_file(str = '')
    temp_path = ''
    Tempfile.open('facts') do |f|
      f.puts str
      temp_path = f.path
    end
    if ENV['EDITOR'].nil? || ENV['EDITOR'].strip.empty?
      raise NoEditorError, 'please set $EDITOR'
    end
    mtime = File.mtime(temp_path)
    system("#{ENV['EDITOR']} #{temp_path}")
    if mtime == File.mtime(temp_path)
      raise NoEditorChangeError, 'temp file not changed, no update needed'
    end
    IO.read(temp_path).strip
  end

  def edit_fact
    fact = Fact.search_one(@arguments.first)
    if @arguments.count == 1
      fact.content = edit_in_temp_file(fact.content)
    else
      fact.content = @arguments.last
    end
    fact.save
    puts 'OK'
  end

  def move_categories
    destination = Category.search_one(@arguments.last)
    @arguments[0..@arguments.count-2].each do |c|
      category = Category.search_one(c)
      category.category_id = destination.id
      category.save
    end
    puts 'OK'
  end

  def move_facts
    destination = Category.search_one(@arguments.last)
    @arguments[0..@arguments.count-2].each do |f|
      fact = Fact.search_one(f)
      fact.category_id = destination.id
      fact.save
    end
    puts 'OK'
  end

  def new_categories
    if @options.parent
      parent = Category.search_one(@arguments.first)
      if @arguments.count == 1
        new_category_names = new_from_temp_file
      else
        new_category_names = @arguments[1..@arguments.count]
      end
    else
      parent = nil
      if @arguments.count == 0
        new_category_names = new_from_temp_file
      else
        new_category_names = @arguments
      end
    end
    categories = []
    new_category_names.each do |c|
      category = Category.new(:name => c)
      category.category_id = parent.id unless parent.nil?
      category.save
      categories.push(category)
    end
    output_categories(categories)
  end

  def new_facts
    category = Category.search_one(@arguments.first)
    if @arguments.count == 1
      new_facts = new_from_temp_file
    else
      new_facts = @arguments[1..@arguments.count]
    end
    new_facts.each do |f|
      fact = Fact.new(:content => f, :category_id => category.id)
      fact.save
      output_facts([fact])
    end
  end

  def new_from_temp_file
    edit_in_temp_file.each.collect{ |l| l.strip }.find_all{ |l| !l.empty? }
  end

  def output_categories(categories)
    categories.each do |c|
      puts "#{c.id} #{c.name} #{c.slug}"
      output_facts(c.facts) if c.facts && c.facts.count > 0
    end
  end

  def output_facts(facts)
    facts.each do |f|
      puts "* #{f.content} (#{f.id})"
    end
  end

  def output_help
    RDoc::usage # exits app
  end

  def output_version
    puts "facts client version #{VERSION}"
  end

  def query_categories
    categories = Category.search_one_or_more(@arguments.first, :include_facts => @options.fact)
    output_categories(categories)
  end

  def query_facts
    facts = Fact.search_one_or_more(@arguments.first)
    output_facts(facts)
  end

  class NoEditorChangeError < RuntimeError
  end

  class NoEditorError < RuntimeError
  end
end

app = FactsClient.new(ARGV, STDIN)
app.run

