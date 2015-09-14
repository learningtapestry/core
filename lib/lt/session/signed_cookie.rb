# Most of this code were taken from rails files:
#
# https://github.com/rails/rails/blob/master/railties/lib/rails/application.rb
# https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/middleware/cookies.rb
#
# and adapted to our needs

require 'action_dispatch/middleware/cookies'
require 'active_support/key_generator'

module LT
  module Session
    module SignedCookie
      class << self

        def unencrypt(value)
          deserialize verify(value)
        end

        def encrypt(value)
          verifier.generate(serialize(value))
        end

        private

          def verifier
            @verifier ||= begin
              secret = key_generator(LT.env.secret_config['secret_key_base']).generate_key('signed cookie')
              ActiveSupport::MessageVerifier.new(secret, digest: 'SHA', serializer: ActiveSupport::MessageEncryptor::NullSerializer)
            end
          end

          def verify(signed_message)
            verifier.verify(signed_message)
          rescue ActiveSupport::MessageVerifier::InvalidSignature
            nil
          end

          def key_generator(secret)
            # number of iterations selected based on consultation with the google security
            # team. Details at https://github.com/rails/rails/pull/6952#issuecomment-7661220
            key_generator = ActiveSupport::KeyGenerator.new(secret, iterations: 1000)
            ActiveSupport::CachingKeyGenerator.new(key_generator)
          end

        protected

          def serialize(value)
            Marshal.dump(value)
          end

          def deserialize(value)
            Marshal.load(value) if value
          end

      end
    end

    module SignedHelpers

      # Cookies can typically store 4096 bytes.
      MAX_COOKIE_SIZE = 4096

      def encrypt_cookie(options)
        if options.is_a?(Hash)
          options.symbolize_keys!
          options[:value] = SignedCookie.encrypt(options[:value])
        else
          options = { :value => SignedCookie.encrypt(options[:value]) }
        end
        options[:value].bytesize > MAX_COOKIE_SIZE ? raise(ActionDispatch::Cookies::CookieOverflow ): options
      end

      def unencrypt_cookie(value)
        SignedCookie.unencrypt(value)
      end

    end
  end
end
