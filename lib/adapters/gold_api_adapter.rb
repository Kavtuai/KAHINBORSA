# frozen_string_literal: true

require_relative 'base_adapter'

class GoldApiAdapter < BaseAdapter
  class << self
    def category
      'precious_metals'
    end

    private

    def build_pairs
      {
        'XAU_USD' => spot_price('XAU'),
        'XAG_USD' => spot_price('XAG')
      }
    end

    def spot_price(symbol)
      payload = HttpClient.get_json("https://api.gold-api.com/price/#{symbol}")
      payload.fetch('price').to_f
    end
  end
end
