# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'
require 'uri'

require_relative 'app_config'
require_relative 'logger_factory'

module HttpClient
  Error = Class.new(StandardError)

  DEFAULT_HEADERS = {
    'Accept' => 'application/json',
    'User-Agent' => 'KAHINBORSA/2.0'
  }.freeze

  module_function

  def get_json(url, headers: {}, query: nil)
    uri = URI(url)
    uri.query = URI.encode_www_form(query) if query && !query.empty?

    request = Net::HTTP::Get.new(uri)
    DEFAULT_HEADERS.merge(headers).each { |key, value| request[key] = value }

    response = perform(uri, request)
    raise Error, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise Error, "Invalid JSON response: #{e.message}"
  end

  def perform(uri, request)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    response = Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == 'https',
      open_timeout: AppConfig.http_open_timeout,
      read_timeout: AppConfig.http_read_timeout,
      write_timeout: AppConfig.http_write_timeout,
      verify_mode: OpenSSL::SSL::VERIFY_PEER
    ) do |http|
      http.request(request)
    end

    AppLogger.debug(
      event: 'http.request',
      uri: uri.to_s,
      code: response.code.to_i,
      duration_ms: elapsed_ms(start)
    )

    response
  rescue StandardError => e
    AppLogger.warn(
      event: 'http.request_failed',
      uri: uri.to_s,
      error_class: e.class.name,
      error_message: e.message,
      duration_ms: elapsed_ms(start)
    )
    raise Error, e.message
  end

  def elapsed_ms(start)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
  end
end
