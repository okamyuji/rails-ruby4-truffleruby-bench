require_relative "boot"

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

module BenchApp
  class Application < Rails::Application
    config.load_defaults 8.1
    config.root = File.expand_path("..", __dir__)
    config.eager_load = true
    config.enable_reloading = false
    config.consider_all_requests_local = false
    config.secret_key_base = "0" * 64
    config.logger = ActiveSupport::Logger.new(nil)
    config.log_level = :fatal
    # load_defaults 8.1 は production で YJIT を自動で有効にするため、YJIT なしを測るときは RAILS_YJIT=false で止める
    config.yjit = ENV.fetch("RAILS_YJIT", "true") == "true"
  end
end
