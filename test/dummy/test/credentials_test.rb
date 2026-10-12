# frozen_string_literal: true

require "test_helper"

class CredentialsTest < ActiveSupport::TestCase
  test "dummy credentials expose shared keys when the master key is available" do
    skip "Set EMBEDDABLE_DUMMY_DEVELOPMENT_KEY, RAILS_MASTER_KEY, or test/dummy/config/master.key" unless master_key_available?

    with_rails_master_key_from_embeddable do
      credentials = Rails.application.credentials
      assert credentials.secret_key_base.present?
      assert_equal "dev_placeholder", credentials.dig(:gem_template, :api_key)
      assert_equal "dev_placeholder", credentials.dig(:smtp, :user_name)
      assert_equal "dev_placeholder", credentials.dig(:smtp, :password)
      assert_equal "dev_placeholder", credentials.dig(:aws, :access_key_id)
      assert_equal "dev_placeholder", credentials.dig(:aws, :secret_access_key)
    end
  end

  private

  def master_key_available?
    ENV["EMBEDDABLE_DUMMY_DEVELOPMENT_KEY"].to_s.strip.present? ||
      ENV["RAILS_MASTER_KEY"].to_s.strip.present? ||
      File.exist?(Rails.root.join("config/master.key"))
  end

  def with_rails_master_key_from_embeddable
    embeddable = ENV["EMBEDDABLE_DUMMY_DEVELOPMENT_KEY"].to_s.strip
    if embeddable.present? && ENV["RAILS_MASTER_KEY"].to_s.strip.empty?
      previous = ENV.fetch("RAILS_MASTER_KEY", nil)
      ENV["RAILS_MASTER_KEY"] = embeddable
      begin
        yield
      ensure
        if previous.nil?
          ENV.delete("RAILS_MASTER_KEY")
        else
          ENV["RAILS_MASTER_KEY"] = previous
        end
      end
    else
      yield
    end
  end
end
