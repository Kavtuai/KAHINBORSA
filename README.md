# KAHINBORSA

<p align="center">
  <img src="assets/kahinborsa-mark.svg" alt="KAHINBORSA banner" width="100%" />
</p>

<p align="center">
  <img alt="Ruby" src="https://img.shields.io/badge/Ruby-3.2%2B-CC342D?logo=ruby&logoColor=white">
  <img alt="Sinatra" src="https://img.shields.io/badge/Sinatra-API-black">
  <img alt="Sequel" src="https://img.shields.io/badge/Sequel-ORM-1f2937">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-2563eb">
</p>

KAHINBORSA is a production-focused market data gateway that consolidates cryptocurrency prices, FX rates, and precious metal quotes behind a single HTTP API.

KAHINBORSA; kripto fiyatlarını, döviz kurlarını ve değerli metal verilerini tek bir HTTP API altında toplayan, üretim odaklı bir piyasa verisi geçididir.

---

## English

### What it does

KAHINBORSA collects data from multiple upstream providers, normalizes pair names, isolates adapter failures, and exposes a compact API for downstream services.

Supported data categories:
- **Crypto:** Binance, BtcTurk, CoinGecko, Kraken, OKX, KuCoin
- **Foreign exchange:** Frankfurter
- **Precious metals:** Gold API
- **Derived conversions:** direct and cross conversions such as `USD/TRY`, `TRY/USD`, `EUR/TRY`, `BTC/TRY`, `ETH/TRY`, `XAU/TRY`

### Why this repository exists

This project is meant for teams that need a clean market-data edge service instead of scattering exchange-specific logic throughout their applications. It keeps the external API surface small while leaving the internals easy to extend.

### Highlights

- Multi-source aggregation with per-adapter fault isolation
- Consistent pair normalization such as `BTC_USD`, `USD_TRY`, `XAU_USD`
- Cross-conversion graph for derived rates
- API key authentication with hashed key storage
- In-memory authentication index to avoid a database lookup on every request
- Rate limiting with Rack::Attack
- Structured logging to STDOUT or file
- Sequel-based database portability through `DATABASE_URL`
- English and Turkish locale support
- Lean HTTP surface with no dashboard or bundled test UI

### Repository layout

```text
api/                Sinatra application entrypoint
bin/                operational scripts
config/             database setup and locale configuration
lib/                adapters, auth, formatting, graph, logging
assets/             README assets
README.md           project guide
LICENSE             MIT license
```

### Quick start

Use this when you want the service running locally with the fewest steps.

#### 1) Install dependencies

```bash
git clone https://github.com/Kavtuai/KAHINBORSA.git
cd KAHINBORSA
bundle install
```

#### 2) Prepare environment variables

```bash
cp .env.example .env
```

Recommended changes before the first run:
- set `API_KEY_PEPPER` to a unique value
- keep `DATABASE_URL` on SQLite for local development unless you already have PostgreSQL or MySQL ready
- leave `SEED_DEFAULT_API_KEY=true` only for local work

#### 3) Create an API key

```bash
bundle exec ruby bin/create_api_key local-admin 120 10
```

The script prints the raw key once. Save it immediately.

#### 4) Start the server

```bash
bundle exec rackup -p 4567
```

#### 5) Verify the service

Public health endpoint:

```bash
curl http://localhost:4567/health
```

Protected market snapshot:

```bash
curl \
  -H "X-API-KEY: <YOUR_API_KEY>" \
  "http://localhost:4567/market?lang=en"
```

Protected conversion endpoint:

```bash
curl \
  -H "X-API-KEY: <YOUR_API_KEY>" \
  "http://localhost:4567/convert?from=USD&to=TRY&amount=100&lang=en"
```

### What you should expect on first boot

- the configured database is created if it does not exist
- the `api_users` table is created or upgraded when required
- a local default key may be seeded in development mode if enabled
- the server answers `GET /health` without authentication
- protected endpoints return `401` until a valid `X-API-KEY` is supplied

### Endpoints

#### `GET /`
Returns a compact service descriptor.

#### `GET /health`
Returns service status, database connectivity state, adapter inventory, and UTC timestamp.

#### `GET /market`
Returns:
- metadata
- adapter health summary
- normalized pair index
- derived conversion pairs
- raw per-source snapshots

Requires `X-API-KEY`.

#### `GET /convert?from=USD&to=TRY&amount=100`
Builds a direct or cross conversion from the current market snapshot.

Requires `X-API-KEY`.

### Example response shape

```json
{
  "status": 200,
  "meta": {
    "service": "KAHINBORSA",
    "version": "2.0.0",
    "timestamp": "2026-04-11 12:00:00 UTC",
    "timezone": "UTC",
    "language": "en",
    "source_count": 8,
    "healthy_source_count": 8,
    "degraded_source_count": 0
  },
  "summary": {
    "available_pairs": ["BTC_TRY", "BTC_USD", "ETH_TRY", "ETH_USD", "EUR_TRY", "USD_TRY", "XAU_USD"],
    "derived_conversions": ["BTC_TRY", "ETH_TRY", "EUR_TRY", "TRY_USD", "USD_TRY", "XAU_TRY"]
  }
}
```

### Configuration reference

The project reads environment variables from `.env` in local development.

| Variable | Purpose | Default |
|---|---|---|
| `DATABASE_URL` | Database connection string | `sqlite://db/kahinborsa.sqlite3` |
| `RACK_ENV` | Environment name | `development` |
| `PORT` | Rack port if used by your process manager | `4567` |
| `APP_VERSION` | Exposed service version | `2.0.0` |
| `LOG_LEVEL` | Logger severity threshold | `info` |
| `LOG_TARGET` | `stdout` or file path | `stdout` |
| `API_KEY_PEPPER` | Server-side pepper used during key hashing | `change-me-in-production` |
| `DEFAULT_RATE_LIMIT` | Fallback requests per minute | `30` |
| `MARKET_CACHE_TTL_SECONDS` | Snapshot cache lifetime | `10` |
| `MARKET_CACHE_SIZE_MB` | In-memory cache capacity | `32` |
| `HTTP_OPEN_TIMEOUT` | Upstream connection timeout in seconds | `2` |
| `HTTP_READ_TIMEOUT` | Upstream read timeout in seconds | `4` |
| `HTTP_WRITE_TIMEOUT` | Upstream write timeout in seconds | `2` |
| `SEED_DEFAULT_API_KEY` | Seed a local key automatically | `true` |
| `DEFAULT_API_KEY` | Local-only seeded key value | `KAHINBORSA-LOCAL-CHANGE-ME` |
| `DEFAULT_API_KEY_NAME` | Display name of the seeded key | `local-admin` |
| `DEFAULT_API_KEY_RATE_LIMIT` | Rate limit for the seeded key | `120` |
| `DEFAULT_API_KEY_CACHE_TTL` | Reserved for future per-client cache policy work | `10` |
| `DB_MAX_CONNECTIONS` | Sequel pool size | `10` |
| `DB_CONNECT_TIMEOUT` | Database connect timeout in seconds | `5` |
| `DB_CONNECTION_VALIDATION_TIMEOUT` | Pool validation interval in seconds | `60` |
| `AUTH_CACHE_TTL_SECONDS` | Authentication index refresh interval | `15` |
| `AUTH_USAGE_WRITE_INTERVAL_SECONDS` | Minimum interval between `last_used_at` writes for the same key | `60` |

### Database support

KAHINBORSA uses Sequel and accepts any compatible `DATABASE_URL`.

#### SQLite
Good default for local development.

```bash
DATABASE_URL=sqlite://db/kahinborsa.sqlite3
```

#### PostgreSQL

```bash
DATABASE_URL=postgres://user:password@localhost:5432/kahinborsa
```

#### MySQL

```bash
DATABASE_URL=mysql2://user:password@localhost:3306/kahinborsa
```

### Security model

- API keys are stored as SHA-256 digests with a server-side pepper
- plaintext key storage is not used for newly generated keys
- authentication uses an in-memory index backed by periodic refresh
- rate limiting can be keyed per API token
- failures from upstream exchanges are isolated from the rest of the snapshot
- client responses do not include upstream stack traces
- strict response headers are enabled by default

### Logging

Structured JSON logs are emitted to `stdout` by default.

Examples:
- `request.completed`
- `request.failed`
- `adapter.failed`
- `adapter.crashed`
- `http.request`
- `http.request_failed`

To log into a file:

```bash
LOG_TARGET=log/production.log
```

### Adding a new adapter

1. Create a class under `lib/adapters/` that inherits from `BaseAdapter`
2. Return normalized pairs such as `BTC_USD`
3. Add the adapter class to `MarketAggregator::ADAPTERS`
4. Keep adapter logic limited to fetching and pair extraction
5. Raise clean exceptions and let the base adapter handle the failure payload

Minimal example:

```ruby
# frozen_string_literal: true

require_relative 'base_adapter'

class ExampleExchangeAdapter < BaseAdapter
  class << self
    def category
      'crypto'
    end

    private

    def build_pairs
      payload = HttpClient.get_json('https://example.com/ticker')

      {
        'BTC_USD' => payload.fetch('btc_usd').to_f,
        'ETH_USD' => payload.fetch('eth_usd').to_f
      }
    end
  end
end
```

### Local validation

Before opening a pull request or tagging a release, run:

```bash
ruby bin/check
```

`bin/check` performs a repository-level syntax pass and a small environment sanity check without requiring application boot.

### Troubleshooting

#### `401 unauthorized`
The `X-API-KEY` header is missing, invalid, disabled, or hashed with a different pepper than the running server.

#### `429 rate_limit_exceeded`
The client exceeded its current request budget. Slow the caller or raise the configured limit for that key.

#### `conversion_not_available`
The requested pair cannot be derived from the current market snapshot. Check whether at least one path exists between the requested symbols.

#### database connection failures
Verify the driver gem for your database and confirm that `DATABASE_URL` is valid for Sequel.

### How to contribute

Support is welcome in a few concrete areas:
- new exchange adapters
- database portability improvements
- operational tooling
- documentation corrections
- benchmark data and load-test results
- security review and bug reports

Please keep contributions focused, reviewable, and consistent with the existing structure.

Recommended contribution steps:
1. open an issue describing the problem or proposal
2. keep changes scoped to one concern
3. include validation notes in the pull request
4. avoid unrelated formatting churn

### Security reporting

Do not open a public issue for a security flaw that could expose users or infrastructure. Send the details privately to the repository maintainer first.

### License

MIT

---

## Türkçe

### Ne yapar

KAHINBORSA, birden fazla veri sağlayıcısından gelen piyasa verilerini toplar, parite isimlerini normalize eder, adapter hatalarını izole eder ve istemcilere sade bir HTTP API sunar.

Desteklenen veri kategorileri:
- **Kripto:** Binance, BtcTurk, CoinGecko, Kraken, OKX, KuCoin
- **Döviz:** Frankfurter
- **Değerli metaller:** Gold API
- **Türetilmiş dönüşümler:** `USD/TRY`, `TRY/USD`, `EUR/TRY`, `BTC/TRY`, `ETH/TRY`, `XAU/TRY`

### Bu depo neden var

Bu proje, uygulama katmanına her borsa için ayrı entegrasyon mantığı yaymak istemeyen ekipler için tasarlandı. Dışarıya küçük ve net bir API sunarken, içeride genişletilebilir bir yapı korur.

### Öne çıkanlar

- Her adapter için hata izolasyonu olan çok kaynaklı veri toplama
- `BTC_USD`, `USD_TRY`, `XAU_USD` gibi tutarlı parite isimleri
- Çapraz kur üretimi yapan dönüşüm grafı
- Hash'li API anahtarı saklama düzeni
- Her istekte veritabanına gitmeyen bellek içi kimlik doğrulama indeksi
- Rack::Attack ile hız limiti
- STDOUT veya dosyaya yapılandırılabilir loglama
- `DATABASE_URL` üzerinden Sequel tabanlı veritabanı taşınabilirliği
- Türkçe ve İngilizce dil desteği
- Dashboard veya test arayüzü içermeyen sade HTTP yüzeyi

### Dizin yapısı

```text
api/                Sinatra uygulama giriş noktası
bin/                operasyon scriptleri
config/             veritabanı ve locale yapılandırması
lib/                adapterler, auth, formatlama, graph, loglama
assets/             README varlıkları
README.md           proje rehberi
LICENSE             MIT lisansı
```

### Hızlı başlangıç

Projeyi yerelde en kısa yoldan ayağa kaldırmak için aşağıdaki adımları izleyin.

#### 1) Bağımlılıkları kurun

```bash
git clone https://github.com/Kavtuai/KAHINBORSA.git
cd KAHINBORSA
bundle install
```

#### 2) Ortam değişkenlerini hazırlayın

```bash
cp .env.example .env
```

İlk çalıştırma öncesinde tavsiye edilen düzenlemeler:
- `API_KEY_PEPPER` değerini size özel yapın
- Yerel geliştirme için hazır PostgreSQL veya MySQL yoksa `DATABASE_URL` değerini SQLite olarak bırakın
- `SEED_DEFAULT_API_KEY=true` ayarını yalnızca yerel kullanım için açık tutun

#### 3) API anahtarı üretin

```bash
bundle exec ruby bin/create_api_key local-admin 120 10
```

Script ham anahtarı yalnızca bir kez yazar. Hemen güvenli şekilde saklayın.

#### 4) Sunucuyu başlatın

```bash
bundle exec rackup -p 4567
```

#### 5) Servisi doğrulayın

Genel sağlık kontrolü:

```bash
curl http://localhost:4567/health
```

Korunan market anlık görüntüsü:

```bash
curl \
  -H "X-API-KEY: <YOUR_API_KEY>" \
  "http://localhost:4567/market?lang=tr"
```

Korunan dönüşüm uç noktası:

```bash
curl \
  -H "X-API-KEY: <YOUR_API_KEY>" \
  "http://localhost:4567/convert?from=USD&to=TRY&amount=100&lang=tr"
```

### İlk açılışta beklemeniz gerekenler

- Seçilen veritabanı yoksa oluşturulur
- Gerekirse `api_users` tablosu oluşturulur veya güncellenir
- Geliştirme ortamında, ayar açıksa yerel varsayılan anahtar eklenebilir
- `GET /health` isteği kimlik doğrulama olmadan cevap verir
- Korunan uç noktalar, geçerli `X-API-KEY` gelene kadar `401` döner

### Uç noktalar

#### `GET /`
Servisin kısa tanıtım bilgisini döner.

#### `GET /health`
Servis durumu, veritabanı erişimi, adapter listesi ve UTC zaman bilgisini döner.

#### `GET /market`
Şunları döner:
- metadata
- adapter sağlık özeti
- normalize edilmiş parite indeksi
- türetilmiş dönüşüm çiftleri
- kaynak bazlı ham snapshot verisi

`X-API-KEY` gerektirir.

#### `GET /convert?from=USD&to=TRY&amount=100`
Güncel piyasa snapshot verisinden doğrudan veya çapraz dönüşüm hesaplar.

`X-API-KEY` gerektirir.

### Yapılandırma özeti

Yerel geliştirmede ortam değişkenleri `.env` dosyasından okunur.

| Değişken | Amaç | Varsayılan |
|---|---|---|
| `DATABASE_URL` | Veritabanı bağlantı cümlesi | `sqlite://db/kahinborsa.sqlite3` |
| `RACK_ENV` | Ortam adı | `development` |
| `PORT` | Process manager kullanıyorsanız Rack portu | `4567` |
| `APP_VERSION` | Servisin dışarı açılan sürümü | `2.0.0` |
| `LOG_LEVEL` | Logger seviye eşiği | `info` |
| `LOG_TARGET` | `stdout` veya dosya yolu | `stdout` |
| `API_KEY_PEPPER` | Anahtar hashleme sırasında kullanılan sunucu tarafı pepper | `change-me-in-production` |
| `DEFAULT_RATE_LIMIT` | Varsayılan dakika başı istek limiti | `30` |
| `MARKET_CACHE_TTL_SECONDS` | Snapshot cache süresi | `10` |
| `MARKET_CACHE_SIZE_MB` | Bellek içi cache kapasitesi | `32` |
| `HTTP_OPEN_TIMEOUT` | Upstream bağlantı zaman aşımı | `2` |
| `HTTP_READ_TIMEOUT` | Upstream okuma zaman aşımı | `4` |
| `HTTP_WRITE_TIMEOUT` | Upstream yazma zaman aşımı | `2` |
| `SEED_DEFAULT_API_KEY` | Yerel varsayılan anahtarı otomatik ekler | `true` |
| `DEFAULT_API_KEY` | Sadece yerel kullanım için varsayılan anahtar | `KAHINBORSA-LOCAL-CHANGE-ME` |
| `DEFAULT_API_KEY_NAME` | Varsayılan anahtarın görünen adı | `local-admin` |
| `DEFAULT_API_KEY_RATE_LIMIT` | Varsayılan anahtar limiti | `120` |
| `DEFAULT_API_KEY_CACHE_TTL` | İleriye dönük istemci bazlı cache politikası için ayrılmış alan | `10` |
| `DB_MAX_CONNECTIONS` | Sequel havuz boyutu | `10` |
| `DB_CONNECT_TIMEOUT` | Veritabanı bağlantı zaman aşımı | `5` |
| `DB_CONNECTION_VALIDATION_TIMEOUT` | Havuz doğrulama aralığı | `60` |
| `AUTH_CACHE_TTL_SECONDS` | Auth indeksinin yenilenme aralığı | `15` |
| `AUTH_USAGE_WRITE_INTERVAL_SECONDS` | Aynı anahtar için `last_used_at` yazımları arasındaki en düşük süre | `60` |

### Veritabanı desteği

KAHINBORSA, Sequel kullanır ve uyumlu her `DATABASE_URL` değerini kabul eder.

#### SQLite
Yerel geliştirme için iyi varsayılan seçenektir.

```bash
DATABASE_URL=sqlite://db/kahinborsa.sqlite3
```

#### PostgreSQL

```bash
DATABASE_URL=postgres://user:password@localhost:5432/kahinborsa
```

#### MySQL

```bash
DATABASE_URL=mysql2://user:password@localhost:3306/kahinborsa
```

### Güvenlik modeli

- API anahtarları SHA-256 özetleri ve sunucu tarafı pepper ile tutulur
- Yeni üretilen anahtarlar için düz metin saklama yapılmaz
- Kimlik doğrulama, periyodik yenilenen bellek içi indeks üzerinden yürür
- Hız limiti API anahtarı bazında uygulanabilir
- Upstream sağlayıcı hataları genel snapshot verisini düşürmez
- İstemci yanıtlarına upstream stack trace bilgisi yazılmaz
- Varsayılan olarak sıkı güvenlik başlıkları açıktır

### Loglama

Varsayılan olarak yapılandırılmış JSON loglar `stdout` çıktısına yazılır.

Örnek olay isimleri:
- `request.completed`
- `request.failed`
- `adapter.failed`
- `adapter.crashed`
- `http.request`
- `http.request_failed`

Dosyaya log yazmak için:

```bash
LOG_TARGET=log/production.log
```

### Yeni adapter ekleme

1. `lib/adapters/` altında `BaseAdapter` miras alan bir sınıf oluşturun
2. `BTC_USD` gibi normalize edilmiş pariteler döndürün
3. Sınıfı `MarketAggregator::ADAPTERS` listesine ekleyin
4. Adapter içinde sadece veri çekme ve parite ayıklama mantığı tutun
5. Hata durumunda temiz exception üretin; başarısız yanıtı temel sınıf oluştursun

Kısa örnek:

```ruby
# frozen_string_literal: true

require_relative 'base_adapter'

class ExampleExchangeAdapter < BaseAdapter
  class << self
    def category
      'crypto'
    end

    private

    def build_pairs
      payload = HttpClient.get_json('https://example.com/ticker')

      {
        'BTC_USD' => payload.fetch('btc_usd').to_f,
        'ETH_USD' => payload.fetch('eth_usd').to_f
      }
    end
  end
end
```

### Yerel doğrulama

Pull request açmadan veya yeni sürüm işaretlemeden önce şu komutu çalıştırın:

```bash
ruby bin/check
```

`bin/check`, uygulamayı ayağa kaldırmadan depo genelinde syntax ve temel ortam doğrulaması yapar.

### Sorun giderme

#### `401 unauthorized`
`X-API-KEY` başlığı eksik, geçersiz, pasif durumda veya çalışan sunucunun pepper değeri ile uyumsuz olabilir.

#### `429 rate_limit_exceeded`
İstemci mevcut istek bütçesini aştı. Çağrı sıklığını düşürün veya ilgili anahtarın limitini artırın.

#### `conversion_not_available`
İstenen semboller arasında mevcut snapshot verisinden kurulabilen bir dönüşüm yolu yoktur.

#### veritabanı bağlantı hataları
İlgili veritabanı sürücü gem'inin kurulu olduğunu ve `DATABASE_URL` değerinin Sequel için geçerli olduğunu doğrulayın.

### Geliştirmeye nasıl destek olunabilir

Katkı verilebilecek başlıca alanlar:
- yeni borsa adapterleri
- veritabanı uyumluluğu geliştirmeleri
- operasyon araçları
- dokümantasyon düzeltmeleri
- benchmark veya yük testi sonuçları
- güvenlik incelemesi ve hata bildirimi

Katkı gönderirken şu düzeni korumanız tavsiye edilir:
1. sorunu veya öneriyi issue olarak tanımlayın
2. değişikliği tek bir konuya odaklı tutun
3. pull request içinde doğrulama notlarını ekleyin
4. alakasız format değişikliklerinden kaçının

### Güvenlik bildirimi

Kullanıcıları veya altyapıyı etkileyebilecek bir güvenlik açığı için herkese açık issue açmayın. Önce depo sahibine özel kanaldan bildirim gönderin.

### Lisans

MIT
