# frozen_string_literal: true

require 'dotenv/load'
require 'json'
require 'securerandom'
require 'time'
require 'sinatra/base'
require 'rack/attack'
require 'active_support'
require 'active_support/cache'
require 'active_support/core_ext/object/blank'
require 'active_support/isolated_execution_state'
require 'i18n'

require_relative '../config/database'
require_relative '../lib/app_config'
require_relative '../lib/auth_manager'
require_relative '../lib/logger_factory'
require_relative '../lib/market_aggregator'
require_relative '../lib/formatter'
require_relative '../lib/market_graph'

I18n.load_path = Dir[File.expand_path('../config/locales.yml', __dir__)]
I18n.default_locale = :en
I18n.available_locales = %i[en tr]

AppCache = ActiveSupport::Cache::MemoryStore.new(size: AppConfig.cache_size_mb * 1024 * 1024)
Rack::Attack.cache.store = AppCache

class KahinBorsaApp < Sinatra::Base
  configure do
    disable :show_exceptions
    disable :raise_errors
    set :protection, except: :path_traversal
    set :server, :puma
    set :logging, false
  end

  use Rack::Attack

  Rack::Attack.throttle('requests by client', limit: proc { |req|
    AuthManager.rate_limit_for(req.get_header('HTTP_X_API_KEY')) || AppConfig.default_rate_limit
  }, period: 60) do |req|
    req.get_header('HTTP_X_API_KEY').presence || req.ip
  end

  Rack::Attack.throttled_responder = lambda do |env|
    request = Rack::Request.new(env)
    body = {
      status: 429,
      error: 'rate_limit_exceeded',
      message: I18n.t('errors.rate_limit_exceeded', locale: request.params['lang'] == 'tr' ? :tr : :en)
    }

    [429, { 'Content-Type' => 'application/json; charset=utf-8' }, [JSON.generate(body)]]
  end

  before do
    @request_id = env['HTTP_X_REQUEST_ID'].presence || SecureRandom.uuid
    @lang = normalize_locale(params[:lang])
    I18n.locale = @lang.to_sym

    headers(
      'Content-Type' => 'application/json; charset=utf-8',
      'X-Request-Id' => @request_id,
      'X-Content-Type-Options' => 'nosniff',
      'X-Frame-Options' => 'DENY',
      'Referrer-Policy' => 'no-referrer',
      'Permissions-Policy' => 'accelerometer=(), camera=(), geolocation=(), microphone=(), payment=(), usb=()',
      'X-Permitted-Cross-Domain-Policies' => 'none',
      'Content-Security-Policy' => "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
      'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains; preload',
      'Cache-Control' => 'no-store'
    )
  end

  after do
    AppLogger.info(
      event: 'request.completed',
      request_id: @request_id,
      method: request.request_method,
      path: request.path,
      status: response.status,
      ip: request.ip
    )
  end

  helpers do
    def normalize_locale(value)
      locale = value.to_s.strip.downcase
      I18n.available_locales.map(&:to_s).include?(locale) ? locale : I18n.default_locale.to_s
    end

    def require_api_key!
      api_key = request.get_header('HTTP_X_API_KEY')

      if AuthManager.authenticate(api_key)
        AuthManager.touch_usage!(api_key)
        return
      end

      halt 401, JSON.generate(
        status: 401,
        error: 'unauthorized',
        message: I18n.t('errors.unauthorized')
      )
    end

    def market_snapshot
      AppCache.fetch(AppConfig.market_cache_key, expires_in: AppConfig.market_cache_ttl_seconds) do
        MarketAggregator.call
      end
    end

    def parse_amount(raw)
      amount = Float(raw || 1)
      raise ArgumentError, 'Amount must be positive.' unless amount.positive?

      amount
    rescue ArgumentError, TypeError
      halt 422, JSON.generate(
        status: 422,
        error: 'invalid_amount',
        message: I18n.t('errors.invalid_amount')
      )
    end
  end

  get '/' do
    JSON.generate(
      service: AppConfig.service_name,
      version: AppConfig.version,
      status: 'ok',
      endpoints: {
        health: '/health',
        market: '/market',
        convert: '/convert?from=USD&to=TRY&amount=1'
      }
    )
  end

  get '/health' do
    JSON.generate(
      service: AppConfig.service_name,
      version: AppConfig.version,
      status: 'ok',
      database: DB.test_connection ? 'connected' : 'disconnected',
      adapters: MarketAggregator.adapter_names,
      timestamp: Time.now.utc.iso8601
    )
  end

  get '/market' do
    require_api_key!

    snapshot = market_snapshot
    formatted_response = Formatter.call(snapshot: snapshot, lang: @lang)
    status formatted_response[:status]
    JSON.generate(formatted_response)
  end

  get '/convert' do
    require_api_key!

    from = params[:from].to_s.upcase
    to = params[:to].to_s.upcase
    amount = parse_amount(params[:amount])

    halt 422, JSON.generate(status: 422, error: 'invalid_symbol', message: I18n.t('errors.invalid_symbol')) if from.empty? || to.empty?

    snapshot = market_snapshot
    conversion = MarketGraph.convert(snapshot[:pair_index], from:, to:, amount:)

    halt 404, JSON.generate(status: 404, error: 'conversion_not_available', message: I18n.t('errors.conversion_not_available')) unless conversion

    JSON.generate(
      status: 200,
      request_id: @request_id,
      timestamp: Formatter.formatted_now(@lang),
      conversion:
        conversion.merge(
          amount: Formatter.round_numeric(amount),
          result: Formatter.round_numeric(conversion[:result])
        )
    )
  end

  not_found do
    status 404
    JSON.generate(status: 404, error: 'not_found', message: I18n.t('errors.not_found'))
  end

  error do
    AppLogger.error(
      event: 'request.failed',
      request_id: @request_id,
      path: request.path,
      error_class: env['sinatra.error']&.class&.name,
      error_message: env['sinatra.error']&.message
    )

    status 500
    JSON.generate(status: 500, error: 'internal_server_error', message: I18n.t('errors.internal_server_error'))
  end
end
