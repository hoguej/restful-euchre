require_relative 'boot'

require 'rails'
# Only require the railties we need for API-only mode
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
# Explicitly do NOT require action_text/engine or other view-related components

Bundler.require(*Rails.groups)

module RestfulEuchre
  class Application < Rails::Application
    config.load_defaults 8.0

    # Configuration for the application, engines, and railties goes here.
    config.api_only = true
  end
end
