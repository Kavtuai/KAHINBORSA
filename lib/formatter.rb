# frozen_string_literal: true

require 'i18n'
require 'tzinfo'
require_relative 'app_config'

class Formatter
  TIMEZONES = {
    'tr' => 'Europe/Istanbul',
    'en' => 'UTC'
  }.freeze

  class << self
    def call(snapshot:, lang:)
      timezone_id = TIMEZONES.fetch(lang, 'UTC')

      {
        status: 200,
        meta: {
          service: AppConfig.service_name,
          version: AppConfig.version,
          timestamp: formatted_now(lang),
          timezone: timezone_id,
          language: lang,
          source_count: snapshot[:sources].size,
          healthy_source_count: snapshot[:health][:active],
          degraded_source_count: snapshot[:health][:degraded]
        },
        summary: {
          available_pairs: snapshot[:pair_index].keys.sort,
          derived_conversions: snapshot[:derived_pairs].keys.sort
        },
        derived_pairs: snapshot[:derived_pairs],
        pair_index: snapshot[:pair_index],
        source_health: snapshot[:health],
        sources: snapshot[:sources]
      }
    end

    def formatted_now(lang)
      timezone_id = TIMEZONES.fetch(lang, 'UTC')
      TZInfo::Timezone.get(timezone_id).now.strftime(I18n.t(:time_format, locale: lang.to_sym))
    end

    def round_numeric(value)
      return value unless value.is_a?(Numeric)

      value.round(8)
    end
  end
end
