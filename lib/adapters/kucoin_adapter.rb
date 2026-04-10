# frozen_string_literal: true

require_relative 'base_adapter'

class KuCoinAdapter < BaseAdapter
  class << self
    def category
      'crypto'
    end

    private

    def build_pairs
      {
        'BTC_USD' => ticker_price('BTC-USDT'),
        'ETH_USD' => ticker_price('ETH-USDT')
      }
    end

    def ticker_price(symbol)
      payload = HttpClient.get_json('https://api.kucoin.com/api/v1/market/orderbook/level1', query: { symbol: symbol })
      payload.fetch('data').fetch('price').to_f
    end
  end
end
