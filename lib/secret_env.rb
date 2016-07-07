require 'secret_env/version'
require 'secret_env/storage'
require 'yaml'

module SecretEnv
  SECRETS_FILE = 'config/secret_env.yml'

  def self.load(env: 'development')
    config = YAML.load_file(SECRETS_FILE).fetch(env)

    storage = Storage.setup(config['storage'])

    env_map = {}
    Array(config.fetch('env')).each do |key, raw_value|
      record = Record.new(key: key, raw_value: raw_value, storage: storage, dependency: env_map)
      env_map[record.key] = record
    end

    env_map.each do |key, record|
      unless ENV.has_key?(record.key)
        ENV[record.key] = record.value
      end
    end
  end

  class Record
    attr_reader :key

    def initialize(key:, raw_value:, storage: Storage::Plain.new, dependency: {})
      @key = key
      @raw_value = raw_value.to_s
      @storage = storage
      @dependency = dependency
    end

    def value
      scanner = StringScanner.new(@raw_value)
      parts = []
      while part = scanner.scan_until(/#\{(.*?)\}/)
        secret_key = scanner.matched[2..-2] # Extract "secret" from "\#{secret}"


        secret = case
                 when ENV.has_key?(secret_key)
                   ENV[secret_key]
                 when @dependency.has_key?(secret_key)
                   # FIXME this code may cause infinite loop
                   @dependency[secret_key].value
                 else
                   @storage.retrieve(secret_key)
                 end

        raise SecretEnv::KeyNotFound unless secret
        parts << part.gsub(scanner.matched, secret)
      end
      parts << scanner.rest
      parts.join
    end
  end

  class KeyNotFound < StandardError; end
end

require 'secret_env/rails' if defined?(Rails)
