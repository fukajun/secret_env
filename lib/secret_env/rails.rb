module SecretEnv
  class Railtie < ::Rails::Railtie
    interval = ENV['SECRET_ENV_RETRIEVE_INTERVAL'].to_f if ENV.key?('SECRET_ENV_RETRIEVE_INTERVAL')
    config.before_configuration { SecretEnv.load(env: Rails.env, interval: interval) }
  end
end
