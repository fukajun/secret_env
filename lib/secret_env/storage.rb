module SecretEnv
  module Storage
    class << self
      def setup(config)
        if config
          klass(config.fetch('type')).new(namespace: config['namespace'])
        else
          Storage::Plain.new
        end
      end

      private

      def klass(type)
        case type
        when 'plain'
          Storage::Plain
        when 'credstash'
          require 'rcredstash'
          Storage::CredStash
        when 'file'
          Storage::File
        else
          raise "Unknown storage type: #{type}"
        end
      end
    end

    class Base
      attr_reader :namespace

      def initialize(namespace: '')
        @namespace = namespace
      end

      def retrieve(secret_key)
        raise NotImplemedError
      end

      private

      def full_key(secret_key)
        "#{namespace}#{secret_key}"
      end
    end

    class Plain < Base
      def retrieve(secret_key)
        "#\{#{full_key(secret_key)}\}"
      end
    end

    class CredStash < Base
      def retrieve(secret_key)
        ::CredStash.get(full_key(secret_key), client: kms_client)
      end

      def kms_client
        @kms_client ||= Aws::KMS::Client.new
      end
    end

    class File < Base
      LOCAL_FILE_PATH = 'config/secret_env.local'

      def initialize(namespace: '')
        super
        @secrets = Hash[*::File.readlines(LOCAL_FILE_PATH).map(&:strip).map {|line| line.split("=", 2) }.flatten]
      end

      def retrieve(secret_key)
        @secrets[full_key(secret_key)]
      end
    end
  end
end
