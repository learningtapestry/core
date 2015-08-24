require 'active_support/concern'

module LT
  module ActiveRecordUtil
    module Rememberable
      extend ActiveSupport::Concern

      # The time the user will be remembered without asking for credentials again.
      mattr_accessor :remember_for
      @@remember_for = 2.weeks

      # If true, extends the user's remember period when remembered via cookie.
      mattr_accessor :extend_remember_period
      @@extend_remember_period = false

      # If true, all the remember me tokens are going to be invalidated when the user signs out.
      mattr_accessor :expire_all_remember_me_on_sign_out
      @@expire_all_remember_me_on_sign_out = true

      attr_accessor :remember_me, :extend_remember_period

      # Generate a new remember token and save the record without validations
      # if remember expired (token is no longer valid) or extend_remember_period is true
      def remember_me!(extend_period=false)
        self.remember_token = self.class.remember_token if generate_remember_token?
        self.remember_created_at = Time.now.utc if generate_remember_timestamp?(extend_period)
        self.save(validate: false) if self.changed?
      end

      # If the record is persisted, remove the remember token (but only if
      # it exists), and save the record without validations.
      def forget_me!
        return unless persisted?
        self.remember_token = nil if respond_to?(:remember_token=)
        self.remember_created_at = nil if expire_all_remember_me_on_sign_out
        save(validate: false)
      end

      def generate_remember_token? #:nodoc:
        respond_to?(:remember_token) && remember_expired?
      end

      # Generate a timestamp if extend_remember_period is true, if no remember_token
      # exists, or if an existing remember token has expired.
      def generate_remember_timestamp?(extend_period) #:nodoc:
        extend_period || remember_expired?
      end

      # Remember token should be expired if expiration time not overpass now.
      def remember_expired?
        remember_created_at.nil? || (remember_expires_at <= Time.now.utc)
      end

      # Remember token expires at created time + remember_for configuration
      def remember_expires_at
        remember_created_at + remember_for
      end

      def remember_cookie_values
        options = { httponly: true }
        options.merge!(
          value: self.class.serialize_into_cookie(self),
          expires: self.remember_expires_at
        )
      end

      class_methods do

        # Generate a token checking if one does not already exist in the database.
        def remember_token #:nodoc:
          loop do
            # binding.pry
            token = friendly_token
            break token unless find_by_remember_token( token )
          end
        end

        # Create the cookie key using the record id and remember_token
        def serialize_into_cookie(record)
          # binding.pry
          Marshal::dump([record.id, record.remember_token])
        end

        # Recreate the user based on the stored cookie
        def serialize_from_cookie(id, remember_token)
          # binding.pry
          record = find(id)
          record if record && !record.remember_expired? &&
                    self.secure_compare(record.remember_token, remember_token)
        end

        # Generate a friendly string randomly to be used as token.
        # By default, length is 20 characters.
        def friendly_token(length = 20)
          rlength = (length * 3) / 4
          SecureRandom.urlsafe_base64(rlength).tr('lIO0', 'sxyz')
        end

        # constant-time comparison algorithm to prevent timing attacks
        def secure_compare(a, b)
          return false if a.blank? || b.blank? || a.bytesize != b.bytesize
          l = a.unpack "C#{a.bytesize}"

          res = 0
          b.each_byte { |byte| res |= byte ^ l.shift }
          res == 0
        end

      end

    end
  end
end
