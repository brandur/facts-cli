require 'json'

module Facts
  class Config
    FactsConfig = File.join(Etc.getpwuid.dir, '.factsrc')
   
    attr_accessor :password, :uri, :user
    
    def initialize
      read
    end

    def uri
      if @uri && !@uri.strip.empty?
        @uri
      else
        'http://facts.brandur.org'
      end
    end
    
    def write
      config = {}

      # Only write user/pass if it looks like credentials have been set
      config['user']     = user     if user
      config['password'] = password if user

      # Only write URI if it's not default
      config['uri']      = @uri     if @uri && !@uri.strip.empty?

      File.open FactsConfig, 'w' do |f|
        f.write(config.to_json)
      end
    end

  private

    def read
      config = if File.exists?(FactsConfig)
        JSON.parse(IO.read(FactsConfig))
      else
        {}
      end
      self.password = config['password']
      self.uri      = config['uri']
      self.user     = config['user']
    end
  end
end
