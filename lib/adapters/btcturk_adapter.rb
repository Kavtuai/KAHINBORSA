# frozen_string_literal: true

require_relative 'base_adapter'

class BtcTurkAdapter < BaseAdapter
  class << self
    def category
      'crypto'
    end

    private

    def build_pairs
      payload = HttpClient.get_json('https://api.btcturk.com/api/v2/ticker').fetch('data')

      {
        'BTC_TRY' => pair_price(payload, 'BTCTRY'),
        'ETH_TRY' => pair_price(payload, 'ETHTRY')
      }
    end

    def pair_price(payload, pair)
      payload.find { |row| row['pair'] == pair }.fetch('last').to_f
    end
  end
end
