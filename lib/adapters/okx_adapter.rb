# frozen_string_literal: true

require_relative 'base_adapter'

class OkxAdapter < BaseAdapter
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

    def ticker_price(inst_id)
      payload = HttpClient.get_json('https://www.okx.com/api/v5/market/ticker', query: { instId: inst_id })
      payload.fetch('data').first.fetch('last').to_f
    end
  end
end
