# frozen_string_literal: true

require_relative 'base_adapter'

class CoinGeckoAdapter < BaseAdapter
  class << self
    def category
      'crypto'
    end

    private

    def build_pairs
      payload = HttpClient.get_json(
        'https://api.coingecko.com/api/v3/simple/price',
        query: {
          ids: 'bitcoin,ethereum',
          vs_currencies: 'usd,try'
        }
      )

      {
        'BTC_USD' => payload.dig('bitcoin', 'usd').to_f,
        'BTC_TRY' => payload.dig('bitcoin', 'try').to_f,
        'ETH_USD' => payload.dig('ethereum', 'usd').to_f,
        'ETH_TRY' => payload.dig('ethereum', 'try').to_f
      }
    end
  end
end
