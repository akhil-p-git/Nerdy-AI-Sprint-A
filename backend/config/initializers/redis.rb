REDIS = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))

# For Rails cache
Rails.application.config.cache_store = :redis_cache_store, {
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
  expires_in: 1.hour
}


