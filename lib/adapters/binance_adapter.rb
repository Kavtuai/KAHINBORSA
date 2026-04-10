# frozen_string_literal: true

require_relative 'base_adapter'

class BinanceAdapter < BaseAdapter
  class << self
    def category
      'crypto'
    end

    private

    def build_pairs
      payload = HttpClient.get_json(
        'https://api.binance.com/api/v3/ticker/price',
        query: { symbols: '["BTCUSDT","ETHUSDT"]' }
      )

      {
        'BTC_USD' => price_for(payload, 'BTCUSDT'),
        'ETH_USD' => price_for(payload, 'ETHUSDT')
      }
    end

    def price_for(payload, symbol)
      payload.find { |row| row['symbol'] == symbol }.fetch('price').to_f
    end
  end
end
