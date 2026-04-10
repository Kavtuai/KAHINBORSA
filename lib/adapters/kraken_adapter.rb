# frozen_string_literal: true

require_relative 'base_adapter'

class KrakenAdapter < BaseAdapter
  class << self
    def category
      'crypto'
    end

    private

    def build_pairs
      payload = HttpClient.get_json(
        'https://api.kraken.com/0/public/Ticker',
        query: { pair: 'XBTUSD,ETHUSD' }
      ).fetch('result')

      {
        'BTC_USD' => last_trade(payload, 'XXBTZUSD'),
        'ETH_USD' => last_trade(payload, 'XETHZUSD')
      }
    end

    def last_trade(payload, symbol)
      payload.fetch(symbol).fetch('c').first.to_f
    end
  end
end
