require 'facts/version'

module Facts
  autoload :Category,      'facts/category'
  autoload :Config,        'facts/config'
  autoload :Fact,          'facts/fact'
  autoload :Set,           'set'
  autoload :UI,            'facts/ui'

  class FactsError < StandardError
    def self.status_code(code = nil)
      define_method(:status_code) { code }
    end
  end

  class ImpreciseQueryError      < FactsError; status_code(2) ; end
  class InternalServerError      < FactsError; status_code(3) ; end
  class JsonParseError           < FactsError; status_code(4) ; end
  class EditorBadExitCodeError   < FactsError; status_code(5) ; end
  class EditorDoesNotExistError  < FactsError; status_code(6) ; end
  class EditorChangeError        < FactsError; status_code(7) ; end
  class UnauthorizedError        < FactsError; status_code(8) ; end
  class UnprocessableEntityError < FactsError; status_code(9) ; end

  class << self
    attr_writer :ui

    def config
      @config ||= Config.new
    end

    def ui
      @ui ||= UI.new
    end
  end
end
