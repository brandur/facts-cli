require 'rubygems/user_interaction'
require 'term/ansicolor'

module Facts
  class UI
    def warn(message)
    end

    def debug(message)
    end

    def error(message)
    end

    def info(message)
    end

    def confirm(message)
    end

    class Shell < UI
      attr_writer :shell

      def initialize(shell)
        @colored = true
        @debug   = ENV['DEBUG']
        @shell   = shell
        @quiet   = false
      end

      def ask(*args)
        Gem::DefaultUserInteraction.ui.ask(*args)
      end

      def ask_for_password(*args)
        Gem::DefaultUserInteraction.ui.ask_for_password(*args)
      end

      def be_mono!
        @colored = false
      end

      def be_quiet!
        @quiet = true
      end
    
      def confirm(msg)
        say(msg, :green) if !@quiet
      end

      def debug!
        @debug = true
      end

      def debug(msg)
        say(msg) if @debug && !@quiet
      end

      def error(msg)
        say(msg, :red)
      end

      def info(msg)
        say(msg) if !@quiet
      end

      def puts(msg)
        say(msg)
      end

      def warn(msg)
        say(msg, :yellow)
      end

    private

      def say(msg, color = nil)
        msg = Term::ANSIColor.uncolored(msg) if !@colored
        @shell.say(msg, color)
      end
    end
  end
end
