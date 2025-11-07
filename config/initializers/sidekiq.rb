require Rails.root.join('lib/redis/config')

schedule_file = 'config/schedule.yml'

Sidekiq.configure_client do |config|
  config.redis = Redis::Config.app
end

# Logs whenever a job is pulled off Redis for execution.
class ChatwootDequeuedLogger
  def call(_worker, job, queue)
    payload = job['args'].first
    Sidekiq.logger.info("Dequeued #{job['wrapped']} #{payload['job_id']} from #{queue}")
    yield
  end
end

Sidekiq.configure_server do |config|
  config.redis = Redis::Config.app

  if ActiveModel::Type::Boolean.new.cast(ENV.fetch('ENABLE_SIDEKIQ_DEQUEUE_LOGGER', false))
    config.server_middleware do |chain|
      chain.add ChatwootDequeuedLogger
    end
  end

  # skip the default start stop logging
  if Rails.env.production?
    config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new
    config[:skip_default_job_logging] = true
    config.logger.level = Logger.const_get(ENV.fetch('LOG_LEVEL', 'info').upcase.to_s)
  end

  # Configure Sidekiq CloudWatch metrics in the server process
  if ENV['ENABLE_SIDEKIQ_CLOUDWATCH'].present?
    require 'sidekiq/cloudwatchmetrics'

    Rails.logger.info '================================================'
    Rails.logger.info 'Sidekiq::CloudWatchMetrics defined (Server Process)'
    Rails.logger.info "ENV['ENABLE_SIDEKIQ_CLOUDWATCH'] #{ENV.fetch('ENABLE_SIDEKIQ_CLOUDWATCH', nil)}"
    Rails.logger.info "ENV['SIDEKIQ_CLOUDWATCH_NAMESPACE'] #{ENV.fetch('SIDEKIQ_CLOUDWATCH_NAMESPACE', nil)}"
    Rails.logger.info "ENV['SIDEKIQ_CLOUDWATCH_INTERVAL'] #{ENV.fetch('SIDEKIQ_CLOUDWATCH_INTERVAL', nil)}"
    Rails.logger.info '================================================'

    # Configure AWS CloudWatch client with explicit instance role credentials
    cloudwatch_client = Aws::CloudWatch::Client.new(
      region: ENV.fetch('AWS_REGION', 'us-east-1'),
      credentials: Aws::InstanceProfileCredentials.new
    )

    # Enable Sidekiq CloudWatch metrics with the configured client
    Sidekiq::CloudWatchMetrics.enable!(
      namespace: ENV.fetch('SIDEKIQ_CLOUDWATCH_NAMESPACE', 'Chatwoot/Sidekiq'),
      interval: ENV.fetch('SIDEKIQ_CLOUDWATCH_INTERVAL', '60').to_i,
      client: cloudwatch_client
    )
  end
end

# https://github.com/ondrejbartas/sidekiq-cron
Rails.application.reloader.to_prepare do
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file) if File.exist?(schedule_file) && Sidekiq.server?
end
