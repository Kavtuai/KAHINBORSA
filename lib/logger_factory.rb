# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'logger'
require 'time'
require_relative 'app_config'

module LoggerFactory
  LEVELS = {
    'debug' => Logger::DEBUG,
    'info' => Logger::INFO,
    'warn' => Logger::WARN,
    'error' => Logger::ERROR,
    'fatal' => Logger::FATAL
  }.freeze

  module_function

  def build
    logger = Logger.new(log_device)
    logger.level = LEVELS.fetch(AppConfig.log_level, Logger::INFO)
    logger.formatter = lambda do |severity, datetime, _progname, message|
      payload = message.is_a?(Hash) ? message : { message: message.to_s }
      JSON.generate(payload.merge(level: severity, timestamp: datetime.utc.iso8601)) << "\n"
    end
    logger
  end

  def log_device
    return $stdout if AppConfig.log_target == 'stdout'

    FileUtils.mkdir_p(File.dirname(AppConfig.log_target))
    AppConfig.log_target
  end
end

AppLogger = LoggerFactory.build
