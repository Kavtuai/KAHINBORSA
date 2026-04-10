# frozen_string_literal: true

require_relative '../http_client'
require_relative '../logger_factory'

class BaseAdapter
  class << self
    def fetch
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      pairs = build_pairs

      {
        source: source_name,
        category: category,
        status: 'active',
        latency_ms: elapsed_ms(started_at),
        pairs: compact_pairs(pairs)
      }
    rescue HttpClient::Error => e
      failure_payload('UPSTREAM_HTTP_ERROR', e, started_at)
    rescue StandardError => e
      failure_payload('UPSTREAM_PARSE_ERROR', e, started_at)
    end

    def source_name
      name.gsub(/Adapter$/, '')
    end

    def category
      'market'
    end

    private

    def compact_pairs(pairs)
      pairs.each_with_object({}) do |(pair, value), memo|
        next unless value.is_a?(Numeric) && value.positive?

        memo[pair.to_s] = value.to_f.round(8)
      end
    end

    def failure_payload(error_code, exception, started_at)
      AppLogger.warn(
        event: 'adapter.failed',
        source: source_name,
        error_code:,
        error_class: exception.class.name,
        error_message: exception.message,
        latency_ms: elapsed_ms(started_at)
      )

      {
        source: source_name,
        category: category,
        status: 'offline',
        error_code:,
        latency_ms: elapsed_ms(started_at),
        pairs: {}
      }
    end

    def elapsed_ms(started_at)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(2)
    end
  end
end
