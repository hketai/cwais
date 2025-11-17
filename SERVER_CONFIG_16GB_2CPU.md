# 16GB RAM, 2 vCPU, 50GB SSD Sunucu Konfigürasyonu

## 📊 Bu Konfigürasyon İçin Öneriler

### Sunucu Özellikleri
- **RAM**: 16 GiB ✅
- **vCPU**: 2 ⚠️ (Sınırlı)
- **SSD**: 50 GiB ⚠️ (Başlangıç için yeterli)
- **Transfer**: 4 TB ✅ (Yeterli)
- **Maliyet**: $99/ay

## ✅ Artıları

1. **RAM Yeterli**: 16GB, tüm servisler için yeterli
2. **Fiyat/Performans**: $99/ay makul bir fiyat
3. **Başlangıç İçin İdeal**: Orta ölçek uygulamalar için uygun

## ⚠️ Dikkat Edilmesi Gerekenler

### 1. CPU Sınırlaması (2 vCPU)
**Sorun**: 
- 2 vCPU, özellikle AI işlemleri (Saturn AI) ve yoğun background job'lar için sınırlı
- WebSocket bağlantıları CPU kullanır
- PostgreSQL query'leri CPU kullanır

**Çözüm**:
```bash
# Puma workers sayısını düşük tutun
WEB_CONCURRENCY=1  # 2 vCPU için 1 worker yeterli
RAILS_MAX_THREADS=5

# Sidekiq concurrency'yi optimize edin
SIDEKIQ_CONCURRENCY=10  # 15 yerine 10
```

### 2. Disk Alanı (50GB)
**Sorun**:
- PostgreSQL veritabanı büyüdükçe alan tüketir
- Log dosyaları birikir
- File upload'lar (Active Storage) disk kullanır

**Çözüm**:
```bash
# File storage için S3/Cloud Storage kullanın
# config/storage.yml'de S3 yapılandırması yapın

# Log rotation ayarlayın
# config/environments/production.rb
config.logger = ActiveSupport::Logger.new(
  Rails.root.join('log', 'production.log'),
  5,  # 5 dosya tut
  10.megabytes  # Her dosya max 10MB
)

# PostgreSQL için düzenli VACUUM
# Cron job ekleyin
0 3 * * * psql -U postgres -d chatwoot -c "VACUUM ANALYZE;"
```

## 🎯 Önerilen Servis Dağılımı

### Senaryo 1: Tek Sunucuda Tüm Servisler (Başlangıç)
```
16GB RAM, 2 vCPU, 50GB SSD

RAM Dağılımı:
├── Rails (1 worker, 5 threads): ~400MB
├── Sidekiq (1 process, 10 concurrency): ~300MB
├── PostgreSQL: ~4GB (shared_buffers: 4GB)
├── Redis: ~500MB
├── Nginx: ~50MB
└── Sistem + Buffer: ~11GB (yeterli)

CPU Kullanımı:
├── Rails: 1 vCPU
├── Sidekiq: 0.5 vCPU
├── PostgreSQL: 0.3 vCPU
└── Sistem: 0.2 vCPU

Disk Kullanımı:
├── Sistem: ~10GB
├── PostgreSQL: ~15-20GB (başlangıç)
├── Logs: ~5GB (rotation ile)
├── Application: ~2GB
└── Buffer: ~15GB (büyüme için)
```

### Senaryo 2: Ayrılmış Sunucular (Önerilen - Büyüme için)
```
Sunucu 1: Application (16GB RAM, 2 vCPU) - $99/ay
├── Rails (1 worker)
├── Sidekiq (1 process)
└── Nginx

Sunucu 2: Database (8GB RAM, 2 vCPU, 100GB SSD) - ~$50/ay
├── PostgreSQL
└── Redis

Toplam: ~$150/ay
```

## ⚙️ Optimizasyon Ayarları

### config/puma.rb
```ruby
# 2 vCPU için 1 worker yeterli
workers ENV.fetch('WEB_CONCURRENCY', 1)
threads 5, 5
preload_app!
```

### config/sidekiq.yml
```yaml
production:
  :concurrency: 10  # 2 vCPU için 10 yeterli
```

### PostgreSQL (postgresql.conf)
```conf
# 16GB RAM için
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 16MB
maintenance_work_mem = 1GB
max_connections = 50  # Tek sunucuda düşük tutun
```

### Redis (redis.conf)
```conf
maxmemory 1gb
maxmemory-policy allkeys-lru
# Production'da persistence gerekmiyorsa
save ""
```

### .env Production
```bash
# Application
WEB_CONCURRENCY=1
RAILS_MAX_THREADS=5
RAILS_MIN_THREADS=5
DATABASE_POOL=10  # (workers * threads) + 5

# Sidekiq
SIDEKIQ_CONCURRENCY=10

# PostgreSQL
DATABASE_URL=postgresql://user:pass@localhost:5432/chatwoot

# Redis
REDIS_URL=redis://localhost:6379/0
REDIS_PASSWORD=your_secure_password

# Storage (S3 kullanın!)
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_REGION=eu-central-1
AWS_BUCKET=your-bucket-name
```

## 📈 Beklenen Performans

### Kapasite
- **Aktif Kullanıcı**: 1000-1500 eşzamanlı
- **WebSocket Bağlantıları**: ~500-800
- **Günlük Mesaj**: 10,000-50,000
- **Background Jobs**: Dakikada ~100-200 job

### Sınırlamalar
- **CPU**: Yoğun AI işlemleri sırasında yavaşlama olabilir
- **Disk**: 50GB, büyüme için yetersiz (S3 kullanın!)
- **vCPU**: 2 core, yüksek trafikte bottleneck olabilir

## 🚀 Deployment Adımları

### 1. Docker Compose Production
```yaml
version: '3'

services:
  rails:
    image: chatwoot/chatwoot:latest
    deploy:
      resources:
        limits:
          cpus: '1.5'
          memory: 1G
    environment:
      - WEB_CONCURRENCY=1
      - RAILS_MAX_THREADS=5
      - DATABASE_POOL=10

  sidekiq:
    image: chatwoot/chatwoot:latest
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 500M
    environment:
      - SIDEKIQ_CONCURRENCY=10

  postgres:
    image: pgvector/pgvector:pg16
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 4G
    environment:
      - POSTGRES_SHARED_BUFFERS=4GB
      - POSTGRES_EFFECTIVE_CACHE_SIZE=12GB

  redis:
    image: redis:alpine
    deploy:
      resources:
        limits:
          cpus: '0.2'
          memory: 1G
```

### 2. Systemd Service Files
```ini
# /etc/systemd/system/chatwoot-rails.service
[Service]
MemoryMax=1.5G
CPUQuota=150%  # 1.5 vCPU
```

## 💡 İyileştirme Önerileri

### Kısa Vadede
1. ✅ **S3 Storage**: File upload'ları S3'e taşıyın
2. ✅ **CDN**: Static asset'ler için Cloudflare/CDN
3. ✅ **Log Rotation**: Log dosyalarını düzenli temizleyin
4. ✅ **Database Indexing**: Query performansını artırın

### Orta Vadede (Büyüme ile)
1. ⬆️ **CPU Upgrade**: 2 → 4 vCPU (daha iyi performans)
2. ⬆️ **Disk Upgrade**: 50GB → 100GB (daha fazla veri)
3. 🔄 **Database Ayrı Sunucu**: PostgreSQL'i ayrı sunucuya taşıyın

### Uzun Vadede
1. 🔄 **Horizontal Scaling**: Load balancer + multiple instances
2. 🔄 **Database Replication**: Read replicas ekleyin
3. 🔄 **Redis Cluster**: Yüksek kullanılabilirlik için

## ✅ Sonuç

**Bu konfigürasyon (16GB RAM, 2 vCPU, 50GB SSD - $99/ay):**

✅ **UYGUN** - Başlangıç ve orta ölçek için
- 1000-1500 aktif kullanıcı için yeterli
- RAM yeterli
- Fiyat makul

⚠️ **DİKKAT**:
- CPU sınırlı (AI işlemleri için 4 vCPU önerilir)
- Disk alanı büyüme için yetersiz (S3 kullanın!)
- Yoğun trafikte scale up gerekebilir

**Öneri**: Bu konfigürasyonla başlayın, büyüdükçe:
1. Önce disk alanını artırın (100GB)
2. Sonra CPU'yu artırın (4 vCPU)
3. Son olarak database'i ayrı sunucuya taşıyın

