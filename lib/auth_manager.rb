# frozen_string_literal: true

require 'digest'
require 'thread'

require_relative '../config/database'
require_relative 'app_config'
require_relative 'logger_factory'

module AuthManager
  module_function

  def authenticate(raw_key)
    user_for(raw_key) != nil
  end

  def rate_limit_for(raw_key)
    user_for(raw_key)&.dig(:rate_limit)
  end

  def user_for(raw_key)
    return nil if raw_key.to_s.strip.empty?

    refresh_cache_if_needed!
    digest = DatabaseConfig.digest_api_key(raw_key)

    CACHE_MUTEX.synchronize do
      CACHE[:users_by_hash][digest]
    end
  end

  def touch_usage!(raw_key)
    user = user_for(raw_key)
    return unless user
    return unless usage_write_due?(user[:id])

    now = Time.now.utc
    DB[:api_users].where(id: user[:id]).update(last_used_at: now, updated_at: now)

    CACHE_MUTEX.synchronize do
      CACHE[:usage_touched_at][user[:id]] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  rescue StandardError => e
    AppLogger.warn(event: 'auth.touch_usage_failed', error_class: e.class.name, error_message: e.message)
  end

  def refresh_cache_if_needed!
    return unless cache_stale?

    CACHE_MUTEX.synchronize do
      return unless cache_stale?

      users = DB[:api_users].where(is_active: true).exclude(api_key_hash: [nil, '']).all
      CACHE[:users_by_hash] = users.each_with_object({}) do |row, memo|
        memo[row[:api_key_hash]] = {
          id: row[:id],
          name: row[:name],
          rate_limit: row[:rate_limit],
          cache_ttl_seconds: row[:cache_ttl_seconds],
          prefix: row[:api_key_prefix]
        }
      end
      CACHE[:loaded_at] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  def cache_stale?
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - CACHE[:loaded_at]) >= AppConfig.auth_cache_ttl_seconds
  end

  def usage_write_due?(user_id)
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    CACHE_MUTEX.synchronize do
      last_touched_at = CACHE[:usage_touched_at][user_id].to_f
      return true if (now - last_touched_at) >= AppConfig.auth_usage_write_interval_seconds

      false
    end
  end

  CACHE = {
    users_by_hash: {},
    usage_touched_at: {},
    loaded_at: 0.0
  }
  CACHE_MUTEX = Mutex.new
end
