require 'spec_helper'

describe "Rails Runner" do
  it "config objects build propperly formatted commands" do
    rails_runner  = LanguagePack::Helpers::RailsRunner.new
    local_storage = rails_runner.detect("active_storage.service")

    expected = 'rails runner "begin; puts %Q{heroku.detecting.config.for.active_storage.service=#{Rails.application.config.try(:active_storage).try(:service)}}; rescue => e; end;"'
    expect(rails_runner.command).to eq(expected)

    rails_runner.detect("assets.compile")

    expected = 'rails runner "begin; puts %Q{heroku.detecting.config.for.active_storage.service=#{Rails.application.config.try(:active_storage).try(:service)}}; rescue => e; end; begin; puts %Q{heroku.detecting.config.for.assets.compile=#{Rails.application.config.try(:assets).try(:compile)}}; rescue => e; end;"'
    expect(rails_runner.command).to eq(expected)
  end

  it "calls run through child object" do
    rails_runner  = LanguagePack::Helpers::RailsRunner.new
    def rails_runner.call; @called ||= 0 ; @called += 1; end
    def rails_runner.called; @called; end

    local_storage = rails_runner.detect("active_storage.service")
    local_storage.success?
    expect(rails_runner.called).to eq(1)

    local_storage.success?
    local_storage.did_match?("foo")
    expect(rails_runner.called).to eq(1)
  end

  it "calls a mock interface" do
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        mock_rails_runner
        expect(File.executable?("bin/rails")).to eq(true)

        rails_runner  = LanguagePack::Helpers::RailsRunner.new
        local_storage = rails_runner.detect("active_storage.service")

        expect(rails_runner.output).to match("heroku.detecting.config.for.active_storage.service=active_storage.service")
        expect(rails_runner.success?).to be(true)
      end
    end
  end

  it "timeout works as expected" do
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        mock_rails_runner("sleep(0.05)")

        rails_runner  = LanguagePack::Helpers::RailsRunner.new(false, 0.01)
        local_storage = rails_runner.detect("active_storage.service")

        expect(rails_runner.success?).to eq(false)
      end
    end
  end

  it "failure in one task does not cause another to fail" do
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        mock_rails_runner('raise "bad" if value == :bad')

        rails_runner  = LanguagePack::Helpers::RailsRunner.new(false, 1)
        bad_value     = rails_runner.detect("bad.value")
        local_storage = rails_runner.detect("active_storage.service")

        expect(!!bad_value.success?).to     eq(false)
        expect(!!local_storage.success?).to eq(true)
      end
    end
  end

  def mock_rails_runner(try_code = "")
        executable_contents = <<-FILE
#!/usr/bin/env ruby

require 'ostruct'

class Object
  def try(value)
    $tried ||= []
    $tried << value
    #{try_code}
    $tried.join(".")
  end
end

module Rails; end

def Rails.application
  OpenStruct.new(config: Object.new)
end

ARGV.shift # remove "runner"

eval(ARGV.join(" "))
FILE
    FileUtils.mkdir("bin")
    File.open("bin/rails", "w") { |f| f << executable_contents }
    File.chmod(0777, "bin/rails")
    ENV["PATH"] = "./bin/:#{ENV['PATH']}" unless ENV["PATH"].include?("./bin:")

    # BUILDPACK_LOG_FILE support for logging
    FileUtils.mkdir("tmp")
    FileUtils.touch("buildpack.log")
  end
end

