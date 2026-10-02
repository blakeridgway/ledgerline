ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Prawn writes each text run as a hex string, splitting runs mid-word when it
    # applies kerning. Decode them and concatenate so assertions can compare
    # readable text.
    def pdf_text(pdf)
      pdf.scan(/<((?:[0-9A-Fa-f]{2})+)>/).flatten.map { |hex| [ hex ].pack("H*") }.join
    end
  end
end
