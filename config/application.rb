require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module LedgerLine
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.eager_load_paths << Rails.root.join("extras")

    # Invoice dates, "worked on" defaults and month boundaries follow this zone.
    # It tracks the machine running the app so "today" matches your wall clock;
    # override it with TZ, e.g. `TZ=America/New_York bin/rails server`.
    local_zone = ENV["TZ"].presence
    if local_zone.nil?
      local_zone = begin
        File.realpath("/etc/localtime")[/zoneinfo\/(.+)\z/, 1]
      rescue StandardError
        nil
      end
    end
    config.time_zone = ActiveSupport::TimeZone[local_zone] ? local_zone : "UTC"
  end
end
