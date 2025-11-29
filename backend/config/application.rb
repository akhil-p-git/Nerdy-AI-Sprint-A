require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module NerdyAiCompanion
  class Application < Rails::Application
    config.load_defaults 8.0
    config.autoload_lib(ignore: %w[assets tasks])

    # API-only mode
    config.api_only = true

    # Enable ActionCable
    config.action_cable.mount_path = '/cable'

    # CORS configuration
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*',
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          expose: ['Authorization']
      end
    end

    # Custom middleware loaded after initialization
    config.after_initialize do
      # Rate limiting, secure headers, and performance monitoring
      # are loaded via initializers after autoload is ready
    end
  end
end
