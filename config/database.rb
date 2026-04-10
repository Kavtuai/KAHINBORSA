# frozen_string_literal: true

require 'digest'
require 'dotenv/load'
require 'logger'
require 'sequel'
require 'time'

module DatabaseConfig
  module_function

  def database_url
    ENV.fetch('DATABASE_URL', 'sqlite://db/kahinborsa.sqlite3')
  end

  def connect
    connection = Sequel.connect(
      database_url,
      max_connections: Integer(ENV.fetch('DB_MAX_CONNECTIONS', 10)),
      connect_timeout: Integer(ENV.fetch('DB_CONNECT_TIMEOUT', 5)),
      test: true
    )

    connection.extension :connection_validator
    connection.pool.connection_validation_timeout = Integer(ENV.fetch('DB_CONNECTION_VALIDATION_TIMEOUT', 60))
    connection
  end

  def ensure_schema!(db)
    create_api_users_table!(db) unless db.table_exists?(:api_users)
    migrate_api_users_table!(db)
    seed_default_api_key!(db)
  end

  def create_api_users_table!(db)
    db.create_table :api_users do
      primary_key :id
      String :name, null: false, default: 'default'
      String :api_key
      String :api_key_prefix, size: 24
      String :api_key_hash, text: true
      Integer :rate_limit, null: false, default: 30
      Integer :cache_ttl_seconds, null: false, default: 10
      TrueClass :is_active, null: false, default: true
      DateTime :last_used_at
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    db.add_index :api_users, :api_key_hash, unique: true
    db.add_index :api_users, :api_key_prefix
    db.add_index :api_users, :is_active
  end

  def migrate_api_users_table!(db)
    schema = db.schema(:api_users).to_h { |name, meta| [name, meta] }

    alter = []
    alter << proc { add_column :name, String, null: false, default: 'default' } unless schema.key?(:name)
    alter << proc { add_column :api_key, String } unless schema.key?(:api_key)
    alter << proc { add_column :api_key_prefix, String, size: 24 } unless schema.key?(:api_key_prefix)
    alter << proc { add_column :api_key_hash, String, text: true } unless schema.key?(:api_key_hash)
    alter << proc { add_column :cache_ttl_seconds, Integer, null: false, default: 10 } unless schema.key?(:cache_ttl_seconds)
    alter << proc { add_column :last_used_at, DateTime } unless schema.key?(:last_used_at)
    alter << proc { add_column :updated_at, DateTime, null: false, default: Sequel::CURRENT_TIMESTAMP } unless schema.key?(:updated_at)

    unless alter.empty?
      db.alter_table(:api_users) do
        alter.each { |statement| instance_exec(&statement) }
      end
    end

    indexes = db.indexes(:api_users).values
    db.add_index(:api_users, :api_key_hash, unique: true) unless indexes.any? { |index| index[:columns] == [:api_key_hash] }
    db.add_index(:api_users, :api_key_prefix) unless indexes.any? { |index| index[:columns] == [:api_key_prefix] }
    db.add_index(:api_users, :is_active) unless indexes.any? { |index| index[:columns] == [:is_active] }

    backfill_key_digests!(db)
  end

  def seed_default_api_key!(db)
    return unless %w[development test].include?(ENV.fetch('RACK_ENV', 'development')) || ENV['SEED_DEFAULT_API_KEY'] == 'true'

    raw_key = ENV.fetch('DEFAULT_API_KEY', 'KAHINBORSA-LOCAL-CHANGE-ME')
    digest = digest_api_key(raw_key)
    return if db[:api_users].where(api_key_hash: digest).count.positive?

    db[:api_users].insert(
      name: ENV.fetch('DEFAULT_API_KEY_NAME', 'local-admin'),
      api_key_prefix: raw_key[0, 12],
      api_key_hash: digest,
      api_key: nil,
      rate_limit: Integer(ENV.fetch('DEFAULT_API_KEY_RATE_LIMIT', 120)),
      cache_ttl_seconds: Integer(ENV.fetch('DEFAULT_API_KEY_CACHE_TTL', 10)),
      is_active: true,
      created_at: Time.now.utc,
      updated_at: Time.now.utc
    )
  end

  def backfill_key_digests!(db)
    dataset = db[:api_users].where(Sequel.|({ api_key_hash: nil }, { api_key_hash: '' })).exclude(api_key: [nil, ''])
    dataset.each do |row|
      raw_key = row[:api_key].to_s
      db[:api_users].where(id: row[:id]).update(
        api_key_prefix: raw_key[0, 12],
        api_key_hash: digest_api_key(raw_key),
        api_key: nil,
        updated_at: Time.now.utc
      )
    end
  end

  def digest_api_key(raw_key)
    Digest::SHA256.hexdigest("#{ENV.fetch('API_KEY_PEPPER', 'kahinborsa-default-pepper')}:#{raw_key}")
  end
end

DB = DatabaseConfig.connect
DatabaseConfig.ensure_schema!(DB)
