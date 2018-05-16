require 'spec_helper'

describe "Rails Runner" do
  it "config objects build propperly formatted commands" do
    rails_runner  = LanguagePack::Helpers::RailsRunner.new
    local_storage = rails_runner.detect("active_storage.service")

    expected = 'rails runner "begin; puts %Q{heroku.detecting.config.for.active_storage.service=#{Rails.application.config.try(:active_storage).try(:service)}}; rescue; end;"'
    expect(rails_runner.command).to eq(expected)

    rails_runner.detect("assets.compile")


    expected = 'rails runner "begin; puts %Q{heroku.detecting.config.for.active_storage.service=#{Rails.application.config.try(:active_storage).try(:service)}}; rescue; end; begin; puts %Q{heroku.detecting.config.for.assets.compile=#{Rails.application.config.try(:assets).try(:compile)}}; rescue; end;"'
    expect(rails_runner.command).to eq(expected)
  end
end
