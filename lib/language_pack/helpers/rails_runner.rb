# frozen_string_literal: true

# This class is used for running `rails runner` against
# apps, primarially for the intention of detecting configuration.
#
# The main benefit of this class is that multiple config
# queries can be grouped together so the application only
# has to be booted once. Calling `did_match` on a
# RailsConfig object will trigger the `rails runner` command
# to be executed.
#
# Example usage:
#
#    rails_config   = RailsRunner.new
#    local_storage  = rails_config.detect("active_storage.service")
#    assets_compile = rails_config.detect("assets.compile")
#
#    local_storage.success?             # => true
#    local_storage.did_match?("local")  # => false
#
#    assets_compile.success?            # => true
#    assets_compile.did_match?("false") # => true
#
class LanguagePack::Helpers::RailsRunner
  # This class is used to help pull configuration values
  # from a rails application. It takes in a configuration key
  # and a reference to the parent RailsRunner object which
  # allows it obtain the `rails runner` output and success
  # status of the operation.
  #
  # For example:
  #
  #    config = RailsConfig.new("active_storage.service", rails_runner)
  #    config.to_command # => "puts %Q{heroku.detecting.config.for.active_storage.service=Rails.application.config.try(:active_storage).try(:service)}; "
  #
  class RailsConfig

    def initialize(config, rails_runner, options={})
      @debug        = options[:debug]
      @rails_runner = rails_runner
      @config       = config
      @heroku_key   = "heroku.detecting.config.for.#{config}"
      @rails_config = String.new('#{')
      @rails_config << 'Rails.application.config'
      config.split('.').each do |part|
        @rails_config << ".try(:#{part})"
      end
      @rails_config << '}'
    end

    def success?
      @rails_runner.success? && @rails_runner.output =~ %r(#{heroku_key})
    end

    def did_match?(val)
      @rails_runner.output =~ %r(#{heroku_key}=#{val})
    end

    def to_command
      cmd = String.new('begin; ')
      cmd << 'puts %Q{'
      cmd << "#{@heroku_key}=#{@rails_config}"
      cmd << '}; '
      cmd << 'rescue => e; '
      cmd << 'puts e; puts e.backtrace; ' if @debug
      cmd << 'end;'
      cmd
    end
  end

  include LanguagePack::ShellHelpers

  def initialize
    @command_array = []
    @output = ""
    @success = false
    @debug = env('HEROKU_DEBUG_RAILS_RUNNER')
    puts "DELETEME: debug is #{@debug}"
  end

  def detect(config_string)
    puts "DELETEME: Detecting #{config_string}"
    config = RailsConfig.new(config_string, self, debug: @debug)
    @command_array << config.to_command
    config
  end

  def output
    puts "DELETEME: getting output"
    @output ||= call
  end

  def success?
    output && @success
  end

  def command
    %Q{rails runner "#{@command_array.join(' ')}"}
  end

  private

    def call
      puts "DELETEME: calling call"
      topic("Detecting rails configuration")
      out = run(command, user_env: true)
      @success = $?.success?
      if @debug
        puts "$ #{command}"
        puts out
      end
      out
    end
end

