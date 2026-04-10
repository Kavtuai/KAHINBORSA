# frozen_string_literal: true

module AppConfig
  module_function

  def service_name
    'KAHINBORSA'
  end

  def version
    ENV.fetch('APP_VERSION', '2.0.0')
  end

  def default_rate_limit
    Integer(ENV.fetch('DEFAULT_RATE_LIMIT', 30))
  end

  def market_cache_ttl_seconds
    Integer(ENV.fetch('MARKET_CACHE_TTL_SECONDS', 10))
  end

  def market_cache_key
    'market:snapshot:v2'
  end

  def cache_size_mb
    Integer(ENV.fetch('MARKET_CACHE_SIZE_MB', 32))
  end

  def http_open_timeout
    Integer(ENV.fetch('HTTP_OPEN_TIMEOUT', 2))
  end

  def http_read_timeout
    Integer(ENV.fetch('HTTP_READ_TIMEOUT', 4))
  end

  def http_write_timeout
    Integer(ENV.fetch('HTTP_WRITE_TIMEOUT', 2))
  end

  def auth_cache_ttl_seconds
    Integer(ENV.fetch('AUTH_CACHE_TTL_SECONDS', 15))
  end

  def auth_usage_write_interval_seconds
    Integer(ENV.fetch('AUTH_USAGE_WRITE_INTERVAL_SECONDS', 60))
  end

  def log_level
    ENV.fetch('LOG_LEVEL', 'info').downcase
  end

  def log_target
    ENV.fetch('LOG_TARGET', 'stdout')
  end
end
