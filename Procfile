web: bundle exec passenger start -p $PORT --max-pool-size 1
worker: bundle exec sidekiq -q highest -q high -q default -q low -q lowest
