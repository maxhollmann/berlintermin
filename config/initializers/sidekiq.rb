Sidekiq.configure_server do |config|
  config.error_handlers << Proc.new do |ex,ctx_hash|
    Rollbar.error ex, ctx_hash
  end
end
