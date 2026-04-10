# frozen_string_literal: true

require_relative 'base_adapter'

class FrankfurterAdapter < BaseAdapter
  class << self
    def category
      'forex'
    end

    private

    def build_pairs
      {
        'USD_TRY' => rate_for('USD', 'TRY'),
        'USD_EUR' => rate_for('USD', 'EUR'),
        'EUR_TRY' => rate_for('EUR', 'TRY'),
        'EUR_USD' => rate_for('EUR', 'USD')
      }
    end

    def rate_for(base, quote)
      payload = HttpClient.get_json("https://api.frankfurter.dev/v2/rate/#{base}/#{quote}")

      return payload.fetch('rate').to_f if payload.is_a?(Hash) && payload.key?('rate')
      return payload.first.fetch('rate').to_f if payload.is_a?(Array) && payload.first.is_a?(Hash) && payload.first.key?('rate')

      raise HttpClient::Error, 'Unsupported Frankfurter response format'
    end
  end
end
