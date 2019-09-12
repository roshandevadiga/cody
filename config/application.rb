require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Cody
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.time_zone = "Pacific Time (US & Canada)"

    config.autoload_paths << Rails.root.join("lib")

    config.filter_parameters << :password

    config.active_job.queue_adapter = :sidekiq

    config.action_mailer.default_url_options = { host: ENV["CODY_HOST"] }

    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]

    # from https://github.com/rails/rails/pull/29180/files#diff-6d52a5cae0f7b90f01bf084772bb0421R10
    initializer "active_support.reset_all_current_attributes_instances" do |app|
      app.executor.to_run { ActiveSupport::CurrentAttributes.reset_all }
      app.executor.to_complete { ActiveSupport::CurrentAttributes.reset_all }
    end
  end
end

if ENV["RAVEN_DSN"]
  sentry_environment = ENV["SENTRY_ENV"] || ENV["RAILS_ENV"]

  Raven.configure do |config|
    config.dsn = ENV["RAVEN_DSN"]
    config.environments = ["production", "staging"]
    config.current_environment = sentry_environment
  end
end
