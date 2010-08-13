require 'json'
require 'optparse'
require 'ostruct'
require 'rdoc/usage'
require 'rest_client'

class FactsClient
  #FactsUri = 'http://facts.brandur.org'
  FactsUri = 'http://localhost:3000'
  Version = '0.1'

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin
    @options = OpenStruct.new
  end

  def run
    begin
      if parsed_options? && arguments_valid?
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
        end
      else
        #output_help
      end
    rescue ImpreciseQueryError, NoEditorError
      $stderr.puts "#{$!}"
    end
  end

  private

  def edit_in_temp_file(str)
    temp_path = ''
    Tempfile.open('facts') do |f|
      f.puts str
      temp_path = f.path
    end
    if ENV['EDITOR'].nil? || ENV['EDITOR'].strip.empty?
      raise NoEditorError, 'please set $EDITOR'
    end
    system("#{ENV['EDITOR']} #{temp_path}")
    IO.read(temp_path).strip
  end

  def edit_category
    category = search_one_category(@arguments.first)
    if @arguments.count == 1
      name = edit_in_temp_file(category.name)
    else
      name = @arguments.last
    end
    update_category(category.db_id, name, category.parent_id)
    puts 'OK'
  end

  def edit_fact
    fact = search_one_fact(@arguments.first)
    if @arguments.count == 1
      content = edit_in_temp_file(fact.content)
    else
      content = @arguments.last
    end
    update_fact(fact.db_id, content, fact.category_id)
    puts 'OK'
  end

  def move_categories
    destination = search_one_category(@arguments.last)
    @arguments[0..@arguments.count-2].each do |c|
      category = search_one_category(c)
      update_category(category.db_id, category.name, destination.db_id)
    end
    puts 'OK'
  end

  def move_facts
    destination = search_one_category(@arguments.last)
    @arguments[0..@arguments.count-2].each do |f|
      fact = search_one_fact(f)
      update_fact(fact.db_id, fact.content, destination.db_id)
    end
    puts 'OK'
  end

  def new_categories
    if @options.parent
      parent = search_one_category(@arguments.first)
      @arguments[1..@arguments.count].each do |c|
        output_categories(new_category(c, parent.db_id))
      end
    else
      @arguments.each do |c|
        output_categories(new_category(c))
      end
    end
  end

  def new_facts
    category = search_one_category(@arguments.first)
    @arguments[1..@arguments.count].each do |f|
      output_facts(new_fact(f, categories.first.db_id))
    end
  end

  def query_categories
    categories = search_one_or_more_categories(@arguments.first, @options.fact)
    output_categories(categories)
  end

  def query_facts
    facts = search_one_or_more_facts(@arguments.first)
    output_facts(facts)
  end

  # Run logic ----
  
  def categories_to_struct(category_hashes)
    category_hashes.
      collect{ |c| c['category'] }.
      # convert child facts to structs as well
      collect do |c| 
        if c.key? 'facts'
          c.merge({ 'facts' => facts_to_struct(c['facts']) })
        else
          c
        end
      end.
      # object.id is reserved so convert to object.db_id instead
      collect{ |c| OpenStruct.new(c.merge({ 'db_id' => c['id'] })) }
  end

  def facts_to_struct(fact_hashes)
    fact_hashes.
      collect{ |f| f['fact'] }.
      # object.id is reserved so convert to object.db_id instead
      collect{ |f| OpenStruct.new(f.merge({ 'db_id' => f['id'] })) }
  end

  def get_category(id)
    categories_to_struct([JSON.parse(RestClient.get("#{FactsUri}/categories/#{id}.json"))]).first
  end

  def output_categories(categories)
    categories.each do |c|
      puts "#{c.db_id} #{c.name} #{c.slug}"
      output_facts(c.facts) if c.facts && c.facts.count > 0
    end
  end

  def output_facts(facts)
    facts.each do |f|
      puts "* #{f.content} (#{f.db_id})"
    end
  end

  def new_category(name, parent_id = '')
    categories_to_struct([JSON.parse(RestClient.post("#{FactsUri}/categories.json", :category => { :name => name, :category_id => parent_id } ))])
  end

  def update_category(id, name, parent_id)
    RestClient.put("#{FactsUri}/categories/#{id}.json", :category => { :name => name, :category_id => parent_id } )
  end

  def new_fact(content, category_id = '')
    facts_to_struct([JSON.parse(RestClient.post("#{FactsUri}/facts.json", :fact => { :content => content, :category_id => category_id } ))])
  end

  def update_fact(id, content, category_id)
    RestClient.put("#{FactsUri}/facts/#{id}.json", :fact => { :content => content, :category_id => category_id } )
  end

  def search_categories(query, include_facts = false)
    categories_to_struct(JSON.parse(RestClient.get("#{FactsUri}/categories/search.json", :params => { :query => query, :include_facts => include_facts })))
  end

  def search_one_category(query, include_facts = false)
    categories = search_one_or_more_categories(query, include_facts)
    categories = categories.find_all{ |c| c.db_id == query || c.name == query }
    if categories.count > 1
      raise ImpreciseQueryError, "more than one category match for query '#{query}'"
    end
    categories[0]
  end

  def search_one_or_more_categories(query, include_facts = false)
    categories = search_categories(query, include_facts)
    if categories.count < 1
      raise ImpreciseQueryError, "no categories matched '#{query}'"
    end
    categories
  end

  def search_facts(query)
    facts_to_struct(JSON.parse(RestClient.get("#{FactsUri}/facts/search.json", :params => { :query => query })))
  end

  def search_one_fact(query)
    facts = search_one_or_more_facts(query)
    facts = facts.find_all{ |c| c.db_id == query || c.content == query }
    if facts.count > 1
      raise ImpreciseQueryError, "more than one fact match for query '#{query}'"
    end
    facts[0]
  end

  def search_one_or_more_facts(query)
    facts = search_facts(query)
    if facts.count < 1
      raise ImpreciseQueryError, "no facts matched '#{query}'"
    end
    facts
  end

  # Command/argument ----

  def arguments_valid?
    if !@options.query && !@options.new && !@options.edit && !@options.move
      $stderr.puts 'An action must be specificied (e.g. query, new, ..)'
      false
    elsif !@options.category && !@options.fact
      $stderr.puts 'A mode must be specified (e.g. category or fact)'
      false
    elsif @options.interactive && get_editor.empty?
      $stderr.puts '$EDITOR must be set for interactive run'
      false
    elsif @options.query && @arguments.count > 1
      $stderr.puts 'Query only supports a single argument'
      false
    elsif @options.new && @arguments.count < 2 && @options.category && @options.parent
      $stderr.puts 'New action must have at least two arguments'
      false
    elsif @options.edit && @arguments.count != 1 && @arguments.count != 2
      $stderr.puts 'Edit takes exactly one or two arguments'
      false
    elsif @options.move && @arguments.count < 2
      $stderr.puts 'Move action must have at least two arguments'
      false
    else
      true
    end
  end

  def output_help
    RDoc::usage # exits app
  end

  def output_version
    puts "facts client version #{VERSION}"
  end

  def parsed_options?
    opts = OptionParser.new
    opts.on('-c', '--category')    { @options.category = true }
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

  class ImpreciseQueryError < RuntimeError
  end

  class NoEditorError < RuntimeError
  end
end

app = FactsClient.new(ARGV, STDIN)
app.run

