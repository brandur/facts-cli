require 'etc'
require 'json'
require 'optparse'
require 'ostruct'
require 'rdoc/usage'
require 'rest_client'
require 'term/ansicolor'

require 'lib/category'
require 'lib/fact'
require 'lib/rest_helper'
require 'lib/restful_record'

class FactsClient
  FactsConfig = File.join(Etc.getpwuid.dir, '.factsrc')

  def initialize(arguments, stdin)
    @arguments = arguments
    @c = Term::ANSIColor
    @stdin = stdin
    @options = OpenStruct.new
  end

  def run
    begin
      if arguments_parsed? && arguments_valid?
        puts "Reading configuration file #{FactsConfig}" if @options.verbose
        file_options = read_config_file
        @options = OpenStruct.new(@options.marshal_dump.merge(file_options))
        RestHelper.user, RestHelper.password = @options.user, @options.password if @options.user
        send("#{@options.action}_#{@options.mode}")
        write_config_file(file_options)
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
    # Actions
    opts.on('-a', '--daily')         { @options.action = :daily }
    opts.on('-d', '--destroy')       { @options.action = :destroy }
    opts.on('-e', '--edit')          { @options.action = :edit }
    opts.on('-m', '--move')          { @options.action = :move }
    opts.on('-n', '--new')           { @options.action = :new }
    opts.on('-q', '--query')         { @options.action = :query }

    # Modes
    opts.on('-c', '--category')      { @options.mode = :category }
    opts.on('-f', '--fact')          { @options.mode = :fact }

    # Authentication
    opts.on('-U', '--user <user>', String) do |u|
      @options.user = u
    end
    opts.on('-P', '--password <password>', String) do |p|
      @options.password = p
    end
    opts.on('-s', '--save-auth')     { @options.save_auth = true }

    # Miscellaneous
    opts.on('-b', '--basic')         { @options.basic = true }
    opts.on('-h', '--help')          { output_help }
    opts.on('-p', '--parent')        { @options.parent = true }
    opts.on('-v', '--verbose')       { @options.verbose = true }

    opts.parse!(@arguments) rescue return false
    true
  end

  def arguments_valid?
    if @options.save && (!@options.user || !@options.password)
      $stderr.puts 'Save flag only meaningful if user/password is supplied'
      false
    elsif (@options.user && !@options.password) || (@options.password && !@options.user)
      $stderr.puts 'Both user and password must be specified'
      false
    elsif @options.action.nil?
      $stderr.puts 'An action must be specificied (e.g. query, new, ..)'
      false
    elsif @options.mode.nil?
      $stderr.puts 'A mode must be specified (e.g. category or fact)'
      false
    elsif @options.action == :query && @arguments.count > 1
      $stderr.puts 'Query only supports a single argument'
      false
    elsif @options.action == :new && @arguments.count < 1 && (@options.mode == :category && @options.parent || @options.mode == :fact)
      $stderr.puts 'New action must have at least one argument'
      false
    elsif @options.action == :edit && @arguments.count != 1 && @arguments.count != 2
      $stderr.puts 'Edit takes exactly one or two arguments'
      false
    elsif @options.action == :move && @arguments.count < 2
      $stderr.puts 'Move action must have at least two arguments'
      false
    elsif @options.action == :destroy && @arguments.count < 1
      $stderr.puts 'Destroy action must have at least one argument'
      false
    else
      true
    end
  end

  def daily_category
    categories = Category.daily
    output_categories(categories)
  end

  def daily_fact
    facts = Fact.daily
    output_facts(facts, true)
  end

  def destroy_category
    @arguments.each do |c|
      category = Category.search_one(c)
      category.destroy
    end
    puts 'OK'
  end

  def destroy_fact
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

  def move_category
    destination = Category.search_one(@arguments.last)
    @arguments[0..@arguments.count-2].each do |c|
      category = Category.search_one(c)
      category.category_id = destination.id
      category.save
    end
    puts 'OK'
  end

  def move_fact
    destination = Category.search_one(@arguments.last)
    @arguments[0..@arguments.count-2].each do |f|
      fact = Fact.search_one(f)
      fact.category_id = destination.id
      fact.save
    end
    puts 'OK'
  end

  def new_category
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

  def new_fact
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
      if @options.basic
        puts "#{c.name} #{c.id} #{c.slug}"
      else
        puts "#{@c.bold { c.name } } #{@c.yellow { c.id.to_s } } #{@c.on_red { c.slug}}"
        puts "#{(0...c.name.length).collect{ '=' }.join}"
      end
      if c.facts && c.facts.count > 0
        output_facts(c.facts)
      else
        puts ''
      end
    end
  end

  def output_facts(facts, standalone = false)
    puts ''
    facts.each do |f|
      if @options.basic
        puts "* #{f.content} (#{f.id})"
      else
        f.content = parse_markdown(f.content)
        puts "#{@c.green { '*' }} #{f.content} #{@c.yellow { f.id.to_s }} #{@c.on_red { f.category.slug } if standalone}"
        puts ''
      end
    end
  end

  def output_help
    RDoc::usage # exits app
  end

  def parse_markdown(str)
    str = str.gsub(/\*\*(.*?)\*\*/, @c.bold('\1'))
    str = str.gsub(/_(.*?)_/, @c.underscore('\1'))
  end

  def query_category
    categories = Category.search_one_or_more(@arguments.first, :include_facts => true)
    output_categories(categories)
  end

  def query_fact
    facts = Fact.search_one_or_more(@arguments.first)
    output_facts(facts, true)
  end

  def read_config_file
    if File.exists?(FactsConfig)
      JSON.parse(IO.read(FactsConfig))
    else
      {}
    end
  end

  def write_config_file(file_options)
    if @options.save_auth
      file_options['user'] = @options.user
      file_options['password'] = @options.password
      File.open FactsConfig, 'w' do |f|
        f.write(file_options.to_json)
      end
      puts "User authentication written to #{FactsConfig}, it contains " + 
           "your password so check its permissions"
    end
  end

  class NoEditorChangeError < RuntimeError
  end

  class NoEditorError < RuntimeError
  end
end

app = FactsClient.new(ARGV, STDIN)
app.run

