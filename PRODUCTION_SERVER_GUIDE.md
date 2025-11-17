# Production Sunucu Rehberi - AISaturn

## 📊 En Çok Tüketilen Kaynaklar

### 1. **RAM (Bellek)** - En Kritik Kaynak ⚠️
- **Rails Uygulaması (Puma)**: Her worker process ~300-500MB
  - Default: 0 workers (tek process) = ~400MB
  - Production önerisi: 2-4 workers = 1.2-2GB
- **Sidekiq Worker**: ~200-400MB per process
  - Default: 10 concurrency = ~300MB
  - Yoğun iş yükü için: 2-3 process = 600MB-1.2GB
- **PostgreSQL**: ~500MB-2GB (veri boyutuna göre)
- **Redis**: ~100-500MB (cache ve job queue)
- **Toplam Minimum**: ~2GB
- **Toplam Önerilen**: ~4-8GB

### 2. **CPU**
- **Rails**: Web request'leri, ActionCable WebSocket bağlantıları
- **Sidekiq**: Background job processing (email, webhook, AI işlemleri)
- **PostgreSQL**: Query execution, index maintenance
- **Önerilen**: 4+ CPU core (2 core minimum)

### 3. **Disk I/O**
- **PostgreSQL**: Veritabanı yazma/okuma
- **Active Storage**: Dosya upload'ları (mesaj ekleri, avatarlar)
- **Redis**: Persistence (RDB/AOF)
- **Önerilen**: SSD disk (minimum 50GB, önerilen 100GB+)

### 4. **Network**
- **WebSocket Bağlantıları**: Her aktif kullanıcı için persistent connection
- **API İstekleri**: External integrations (Shopify, WhatsApp, etc.)
- **Önerilen**: 100Mbps+ bandwidth

## 🖥️ Sunucu Önerileri

### Senaryo 1: Küçük Ölçek (100-500 aktif kullanıcı)
```
Sunucu: 1x VPS/Cloud Instance
- CPU: 4 cores
- RAM: 8GB
- Disk: 100GB SSD
- Network: 100Mbps

Servisler:
- Rails (2 workers) + Sidekiq (1 process) + PostgreSQL + Redis
- Tüm servisler aynı sunucuda
```

### Senaryo 2: Orta Ölçek (500-2000 aktif kullanıcı) - ÖNERİLEN
```
Sunucu 1: Application Server
- CPU: 4-8 cores
- RAM: 16GB
- Disk: 100GB SSD
- Servisler: Rails (3-4 workers) + Sidekiq (2-3 processes)

Sunucu 2: Database Server
- CPU: 4 cores
- RAM: 8GB
- Disk: 200GB SSD (RAID 10 önerilir)
- Servisler: PostgreSQL

Sunucu 3: Cache/Queue Server (Opsiyonel, aynı sunucuda da olabilir)
- CPU: 2 cores
- RAM: 4GB
- Disk: 50GB SSD
- Servisler: Redis
```

### Senaryo 3: Büyük Ölçek (2000+ aktif kullanıcı)
```
Load Balancer (Nginx/HAProxy)
  ↓
Application Servers (2-3x)
  - CPU: 8 cores
  - RAM: 16-32GB
  - Rails (4-6 workers) + Sidekiq (3-4 processes)

Database Server (Primary + Replica)
  - CPU: 8 cores
  - RAM: 16-32GB
  - Disk: 500GB+ SSD (RAID 10)

Redis Cluster
  - 3x Redis instances (sentinel mode)
```

## ⚙️ Production Optimizasyonları

### Environment Variables
```bash
# Puma Workers (CPU core sayısına göre)
WEB_CONCURRENCY=2-4  # 4 core için 2, 8 core için 4
RAILS_MAX_THREADS=5
RAILS_MIN_THREADS=5

# Sidekiq Concurrency
SIDEKIQ_CONCURRENCY=10-20  # İş yüküne göre

# PostgreSQL Connection Pool
DATABASE_POOL=25  # (workers * threads) + 5

# Redis
REDIS_URL=redis://redis-server:6379/0
REDIS_PASSWORD=your_secure_password

# Memory Limits (systemd)
MemoryMax=2G  # Rails için
MemoryMax=1.5G  # Sidekiq için
```

### PostgreSQL Optimizasyonları
```sql
-- shared_buffers: RAM'in %25'i
shared_buffers = 2GB  # 8GB RAM için

-- effective_cache_size: RAM'in %50-75'i
effective_cache_size = 6GB  # 8GB RAM için

-- work_mem: Her connection için
work_mem = 16MB

-- max_connections: Uygulama ihtiyacına göre
max_connections = 100
```

### Redis Optimizasyonları
```conf
# redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lru
save ""  # Production'da persistence gerekmiyorsa
```

## 🐳 Docker Production Deployment

### docker-compose.production.yaml Özelleştirmesi
```yaml
services:
  rails:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 4G
        reservations:
          cpus: '2'
          memory: 2G
    environment:
      - WEB_CONCURRENCY=2
      - RAILS_MAX_THREADS=5
      - DATABASE_POOL=15

  sidekiq:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
    environment:
      - SIDEKIQ_CONCURRENCY=15

  postgres:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
```

## 📈 Monitoring ve Scaling

### İzlenmesi Gereken Metrikler
1. **RAM Kullanımı**: %80 üzerinde ise scale up
2. **CPU Kullanımı**: Sürekli %70+ ise scale up
3. **Database Connections**: Max connections'a yaklaşıyorsa pool artır
4. **Sidekiq Queue Size**: Sürekli büyüyorsa worker sayısını artır
5. **Response Time**: 500ms+ ise optimizasyon gerekli

### Auto-Scaling Stratejisi
- **Horizontal Scaling**: Load balancer ile multiple Rails instances
- **Vertical Scaling**: Sunucu kaynaklarını artırma
- **Database Scaling**: Read replicas ekleme

## 🔒 Güvenlik ve Backup

### Backup Stratejisi
```bash
# PostgreSQL Daily Backup
0 2 * * * pg_dump -U postgres chatwoot > /backups/chatwoot_$(date +\%Y\%m\%d).sql

# Redis Backup (RDB)
save 900 1
save 300 10
save 60 10000

# File Storage Backup
# Active Storage dosyaları için S3/Cloud Storage kullanın
```

### Güvenlik
- Firewall (UFW/iptables): Sadece gerekli portları aç
- SSL/TLS: Let's Encrypt ile HTTPS
- Database: Sadece internal network'ten erişim
- Redis: Password protection + internal network only

## 💰 Maliyet Tahmini (Aylık)

### Senaryo 1: Tek Sunucu
- DigitalOcean: $48-96/ay (8-16GB RAM)
- AWS EC2: $70-140/ay (t3.xlarge)
- Hetzner: $30-60/ay (CPX31-CPX41)

### Senaryo 2: Ayrılmış Sunucular
- Application: $48-96/ay
- Database: $48-96/ay
- Redis: $12-24/ay (veya aynı sunucuda)
- **Toplam**: $108-216/ay

## 🚀 Hızlı Başlangıç Önerisi

**Minimum Production Setup:**
```
1x Sunucu (8GB RAM, 4 CPU, 100GB SSD)
├── Nginx (Reverse Proxy + SSL)
├── Rails (2 workers)
├── Sidekiq (1 process, 10 concurrency)
├── PostgreSQL (ayrı container/process)
└── Redis (ayrı container/process)

Maliyet: ~$40-60/ay
Kapasite: 500-1000 aktif kullanıcı
```

**Önerilen Başlangıç Konfigürasyonu (16GB RAM, 2 vCPU, 50GB SSD - $99/ay):**
```
✅ UYGUN - Orta ölçek için ideal başlangıç

Sunucu: 16GB RAM, 2 vCPU, 50GB SSD
├── Nginx (Reverse Proxy + SSL)
├── Rails (2 workers) - ~1.2GB RAM
├── Sidekiq (1 process, 15 concurrency) - ~400MB RAM
├── PostgreSQL - ~2-4GB RAM
└── Redis - ~500MB RAM

Toplam RAM Kullanımı: ~4-6GB (16GB'ın %25-40'ı)
Kalan RAM: Buffer ve peak yükler için yeterli

Kapasite: 1000-2000 aktif kullanıcı
Maliyet: $99/ay

⚠️ DİKKAT:
- 2 vCPU biraz sınırlı olabilir, yoğun AI işlemleri için 4 vCPU önerilir
- 50GB SSD başlangıç için yeterli, büyüdükçe artırılmalı
- PostgreSQL için ayrı sunucu eklemek daha iyi olur
```

**Önerilen Production Setup:**
```
2x Sunucu
├── App Server (16GB RAM, 4-8 CPU)
│   ├── Rails (3-4 workers)
│   └── Sidekiq (2 processes)
└── DB Server (8GB RAM, 4 CPU)
    ├── PostgreSQL
    └── Redis

Maliyet: ~$100-150/ay
Kapasite: 2000-5000 aktif kullanıcı
```

## 📝 Notlar

- **Saturn AI özellikleri** ekstra CPU/RAM tüketir (vector embeddings, AI processing)
- **WebSocket bağlantıları** memory'de tutulur, aktif kullanıcı sayısına göre planlayın
- **File uploads** için S3/Cloud Storage kullanın (disk yerine)
- **CDN** kullanarak static asset'leri offload edin
- **Database indexing** query performansını önemli ölçüde artırır

