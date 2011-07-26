require 'pathname'
require 'term/ansicolor'
require 'thor'
require 'thor/actions'

module Facts
  class CLI < Thor
    include Thor::Actions

    C = Term::ANSIColor

    # Aliases for our long action names
    map 'd'  => 'daily_facts'
    map 'ec' => 'edit_category'
    map 'ef' => 'edit_fact'
    map 'mc' => 'move_category'
    map 'mf' => 'move_fact'
    map 'nc' => 'new_category'
    map 'nf' => 'new_fact'
    map 'qc' => 'query_category'
    map 'qf' => 'query_fact'
    map 'rc' => 'destroy_category'
    map 'rf' => 'destroy_fact'

    def initialize(*)
      super

      if ['--version', '-v'].include?(ARGV.first)
        Facts.ui.puts "Facts #{Facts::VERSION}"
        exit(0)
      end

      # No color is kind of defined in two places here which isn't exactly
      # ideal
      the_shell = options['no-color'] ? Thor::Shell::Basic.new : shell
      Facts.ui = UI::Shell.new(the_shell)
      Facts.ui.be_mono!  if options['no-color']
      Facts.ui.be_quiet! if options[:quiet]
    end

    check_unknown_options!

    class_option 'no-color', :type => :boolean, :banner => "Disable colorization in output"
    class_option 'quiet',    :type => :boolean, :banner => "Only output warnings and errors"
    class_option 'version',  :type => :boolean, :banner => "Show Facts version and quit", :aliases => '-v'

    desc 'config', "Configure Facts connection"
    long_desc <<-D
      Configures a connection to a Facts server. For write operations against 
      a Facts database to succeed, credentials for that server are required. 
      This task will ask for required parameters, and save them to `.factsrc` 
      for future use.
    D
    def config
      Facts.config.uri      = Facts.ui.ask("URI of Facts host [#{Facts.config.uri}]:")
      Facts.config.user     = Facts.ui.ask("User:")
      if Facts.config.user.nil? || Facts.config.user.strip.empty?
        Facts.ui.error("User cannot be blank")
        exit(0)
      end
      Facts.config.password = Facts.ui.ask_for_password("Password:")
      Facts.config.write
      Facts.ui.confirm("\nWrote: #{Facts::Config::FactsConfig} (change permissions to 600)")
    end

    desc 'daily_facts', "Get a list of daily facts"
    long_desc <<-D
      Queries for a daily digest of facts for consumption and memorization.
    D
    method_option 'num', :type => :numeric, :banner => "Specify the number of facts to retrieve (default 15)", :default => 15, :aliases => '-n'
    def daily_facts
      facts = Fact.daily
      output_facts(facts, true)
    end

    desc 'destroy_category [CATS ...]', "Destroy category(s)"
    long_desc <<-D
      Destroys each category passed in along with all its child categories and 
      facts. Categories can either be an ID or a partial name match.
    D
    def destroy_category(*categories)
      arg_misuse 'need at least one argument' if categories.count < 1
      auth_required
      categories.each do |c|
        category = Category.search_one(c)
        category.destroy
      end
      output_ok
    end

    desc 'destroy_fact [FACTS ...]', "Destroy fact(s)"
    long_desc <<-D
      Destroys each fact passed in as an argument. Facts can either be an ID 
      or a partial content match.
    D
    def destroy_fact(*facts)
      arg_misuse 'need at least one argument' if facts.count < 1
      auth_required
      facts.each do |f|
        fact = Fact.search_one(f)
        fact.destroy
      end
      output_ok
    end

    desc 'edit_category [SRC CAT] [DEST CAT]', "Edit a category"
    long_desc <<-D
      Edits the name of a category. Either provide two arguments containing 
      the category to change (ID or partial name match) and the new desired 
      name, or, just the category to change and $EDITOR will be launched to 
      make the change.
    D
    def edit_category(src, dest = nil)
      category = Category.search_one(src)
      auth_required
      if dest
        category.name = dest
      else
        category.name = edit_in_temp_file(category.name)
      end
      category.save
      output_ok
    end

    desc 'edit_fact [SRC FACT] [DEST CAT]', "Edit a fact"
    long_desc <<-D
      Edits the content of a fact. Either provide two arguments containing the 
      fact to change (ID or partial content match) and the new desired content, 
      name, or, just the fact to change and $EDITOR will be launched to make 
      the change.
    D
    def edit_fact(src, dest = nil)
      fact = Fact.search_one(src)
      auth_required
      if dest
        fact.content = dest
      else
        fact.content = edit_in_temp_file(fact.content)
      end
      fact.save
      output_ok
    end

    desc 'move_category [SRC CATS ...] [DEST CAT]', "Move category(s)"
    long_desc <<-D
      Moves a category or set of categories to a new parent category. All 
      arguments but the last should be categories to move (ID or partial name 
      match), and the last argument should be the destination category. Use 
      the `-p` switch and no destination argument to move categories to the 
      root level.
    D
    method_option 'no-parent', :type => :boolean, :banner => "Categories should be moved to the root level (no longer have a parent)", :aliases => '-p'
    def move_category(*categories)
      arg_misuse 'need at least two arguments' if categories.count < 2 && !options['no-parent']
      auth_required
      dest_id = if !options['no-parent']
        Category.search_one(categories.last).id
      else
        nil
      end
      categories = categories[0..categories.count-2] if !options['no-parent']
      categories.each do |c|
        category = Category.search_one(c)
        category.category_id = dest_id
        category.save
      end
      output_ok
    end

    desc 'move_fact [SRC FACTS ...] [DEST CAT]', "Move fact(s) to a new category"
    long_desc <<-D
      Moves a fact or set of facts to a new parent category. All arguments but 
      the last should be facts to move (ID or partial content match), and the 
      last argument should be the destination category.
    D
    def move_fact(*facts)
      arg_misuse 'need at least two arguments' if facts.count < 2
      auth_required
      dest = Category.search_one(facts.last)
      facts[0..facts.count-2].each do |f|
        fact = Fact.search_one(f)
        fact.category_id = dest.id
        fact.save
      end
      output_ok
    end

    desc 'new_category [PARENT CAT] [CATS ...]', "Create new category(s)"
    long_desc <<-D
      Creates a new category or set of new categories. The first argument 
      should be the parent category to which the new categories will belong 
      (ID or partial name match), and all other arguments should be the names 
      of new categories. Use the `-p` switch with no parent category argument 
      to create the categories at the root level.
    D
    method_option 'no-parent', :type => :boolean, :banner => "Category should have no parent (making it root level)", :aliases => '-p'
    def new_category(*args)
      arg_misuse 'need at least one argument' if args.count < 1
      auth_required
      unless options['no-parent']
        arg_misuse 'need at least two arguments' if args.count < 2
        parent = Category.search_one(args.first)
        if args.count == 1
          new_category_names = new_from_temp_file
        else
          new_category_names = args[1..args.count]
        end
      else
        parent = nil
        if args.count == 0
          new_category_names = new_from_temp_file
        else
          new_category_names = args
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

    desc 'new_fact [CAT] [FACTS ...]', "Create new fact(s)"
    long_desc <<-D
      Creates a new fact or set of new facts. The first argument should be 
      should be the parent category to which the new categories will belong 
      (ID or partial name match), and all other arguments should be content 
      for new facts. If only the parent category is specified, $EDITOR will be 
      lauched and new facts can be entered there (one fact per line).
    D
    def new_fact(*args)
      arg_misuse 'need at least one argument' if args.count < 1
      auth_required
      category = Category.search_one(args.first)
      if args.count == 1
        new_facts = new_from_temp_file
      else
        new_facts = args[1..args.count]
      end
      new_facts.each do |f|
        fact = Fact.new(:content => f, :category_id => category.id)
        fact.save
        output_facts([fact])
      end
    end

    desc 'query_category [CATS ...]', "Query category(s)"
    long_desc <<-D
      Queries for categories. A number of search terms can be entered and 
      categories that match all the search terms will be returned. Use the 
      `--or` switch to return categories that match any of the search terms 
      instead.
    D
    method_option 'no-facts', :type => :boolean, :banner => "Do not include facts with category results", :aliases => '-n'
    method_option 'or', :type => :boolean, :banner => "Perform logical OR instead of AND on results of each term"
    def query_category(*categories)
      arg_misuse 'need at least one argument' if categories.count < 1
      results = query(categories) do |c|
        Category.search_one_or_more(c, :include_facts => !options['no-facts'])
      end
      output_categories(results)
    end

    desc 'query_fact [FACTS ...]', "Query fact(s)"
    long_desc <<-D
      Queries for facts. A number of search terms can be entered and facts 
      that match all the search terms will be returned. Use the `--or` switch 
      to return facts that match any of the search terms instead.
    D
    method_option 'or', :type => :boolean, :banner => "Perform logical OR instead of AND on results of each term"
    def query_fact(*facts)
      arg_misuse 'need at least one argument' if facts.count < 1
      results = query(facts) do |f|
        Fact.search_one_or_more(f)
      end
      output_facts(results, true)
    end

  private

    # Exit because of an argument usage problem. Error code zero because this 
    # isn't really a serious error.
    def arg_misuse(msg)
      Facts.ui.puts(msg)
      exit(0)
    end

    # Exits indicating that authorization is required unless user/pass 
    # combination is properly configured.
    def auth_required
      unless Facts.config.user
        Facts.ui.puts "Authorization required for this task, use `facts config`"
        exit(0)
      end
    end

    def edit_in_temp_file(str = '')
      temp_path = ''
      Tempfile.open('facts') do |f|
        f.puts str
        temp_path = f.path
      end
      if !ENV['EDITOR'] || ENV['EDITOR'].strip.empty?
        raise EditorDoesNotExistError, 'please set $EDITOR'
      end
      mtime = File.mtime(temp_path)
      ret = system("#{ENV['EDITOR']} #{temp_path}")
      # ret is false for a non-zero exit code and nil if command execution 
      # failed
      raise EditorBadExitCodeError, 'editor execution failed or bad return code' unless ret == true
      if mtime == File.mtime(temp_path)
        raise EditorChangeError, 'temp file not changed, no update needed'
      end
      IO.read(temp_path).strip
    end

    def new_from_temp_file
      edit_in_temp_file.each_line.collect{ |l| l.strip }.find_all{ |l| !l.empty? }
    end

    def output_categories(categories)
      categories.each do |c|
        Facts.ui.puts "#{C.underscore{ C.bold{ c.name } } } #{C.yellow{ c.id.to_s } } #{C.on_red{ c.slug}}"
        if c.facts && c.facts.count > 0
          output_facts(c.facts)
        else
          Facts.ui.puts ''
        end
      end
    end

    def output_facts(facts, standalone = false)
      facts.each do |f|
        f.content = pseudo_parse_markdown(f.content)
        Facts.ui.puts "#{C.green{ '*' }} #{f.content} #{C.yellow{ f.id.to_s }} #{C.on_red{ f.category.slug } if standalone}"
        Facts.ui.puts ''
      end
    end

    def output_ok
      Facts.ui.puts "[ #{C.green{ 'OK' }} ]"
    end

    # Best effort to parse some Markdown for display in a terminal.
    def pseudo_parse_markdown(str)
      str = str.gsub(/\*\*(.*?)\*\*/, C.bold('\1'))
      str = str.gsub(/_(.*?)_/, C.underscore('\1'))
      str = str.gsub(/<math>(.*?)<\/math>/, C.bold('\1'))
    end

    def query(objs)
      valid_ids = nil
      valid_results = []
      objs.each do |f|
        results = yield f
        result_ids = results.map{|o| o.id}
        if valid_ids.nil?
          valid_ids = Set.new(result_ids)
        elsif options[:or]
          valid_ids = valid_ids | result_ids
        else
          valid_ids = valid_ids & result_ids
        end
        valid_results = valid_results.concat(results).uniq{|o| o.id}
        valid_results = valid_results.find_all{|o| valid_ids.include?(o.id)}
      end
      valid_results
    end
  end
end

