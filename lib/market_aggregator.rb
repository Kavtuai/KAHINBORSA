# frozen_string_literal: true

require 'thread'

require_relative 'logger_factory'
require_relative 'market_graph'
require_relative 'adapters/binance_adapter'
require_relative 'adapters/btcturk_adapter'
require_relative 'adapters/coingecko_adapter'
require_relative 'adapters/kraken_adapter'
require_relative 'adapters/okx_adapter'
require_relative 'adapters/kucoin_adapter'
require_relative 'adapters/frankfurter_adapter'
require_relative 'adapters/gold_api_adapter'

class MarketAggregator
  ADAPTERS = [
    BinanceAdapter,
    BtcTurkAdapter,
    CoinGeckoAdapter,
    KrakenAdapter,
    OkxAdapter,
    KuCoinAdapter,
    FrankfurterAdapter,
    GoldApiAdapter
  ].freeze

  class << self
    def call
      results = []
      mutex = Mutex.new

      threads = ADAPTERS.map do |adapter|
        Thread.new do
          Thread.current.report_on_exception = false
          response = safe_fetch(adapter)
          mutex.synchronize { results << response }
        end
      end

      threads.each(&:join)
      results.sort_by! { |entry| entry[:source] }

      {
        sources: results,
        health: build_health(results),
        pair_index: build_pair_index(results),
        derived_pairs: nil
      }.tap do |snapshot|
        snapshot[:derived_pairs] = MarketGraph.derive_pairs(snapshot[:pair_index])
      end
    end

    def adapter_names
      ADAPTERS.map(&:source_name)
    end

    private

    def safe_fetch(adapter)
      adapter.fetch
    rescue StandardError => e
      AppLogger.error(
        event: 'adapter.crashed',
        adapter: adapter.name,
        error_class: e.class.name,
        error_message: e.message
      )
      {
        source: adapter.source_name,
        category: adapter.category,
        status: 'offline',
        error_code: 'UNHANDLED_ADAPTER_EXCEPTION',
        pairs: {}
      }
    end

    def build_health(results)
      active = results.count { |entry| entry[:status] == 'active' }
      degraded = results.count - active
      {
        active:,
        degraded:,
        total: results.count
      }
    end

    def build_pair_index(results)
      buckets = Hash.new { |hash, key| hash[key] = [] }

      results.each do |entry|
        next unless entry[:status] == 'active'

        entry.fetch(:pairs, {}).each do |pair, value|
          next unless value.is_a?(Numeric) && value.positive?

          buckets[pair] << { source: entry[:source], price: value.to_f }
        end
      end

      buckets.each_with_object({}) do |(pair, values), memo|
        prices = values.map { |item| item[:price] }
        memo[pair] = {
          price: average(prices),
          source_count: values.size,
          sources: values
        }
      end
    end

    def average(values)
      return 0.0 if values.empty?

      (values.sum / values.size.to_f).round(8)
    end
  end
end
