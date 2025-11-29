module Security
  class EncryptionService
    class << self
      def encrypt(data)
        return nil if data.nil?

        cipher = OpenSSL::Cipher.new('aes-256-gcm')
        cipher.encrypt
        cipher.key = encryption_key
        iv = cipher.random_iv

        encrypted = cipher.update(data.to_s) + cipher.final
        tag = cipher.auth_tag

        Base64.strict_encode64(iv + tag + encrypted)
      end

      def decrypt(encrypted_data)
        return nil if encrypted_data.nil?

        data = Base64.strict_decode64(encrypted_data)

        cipher = OpenSSL::Cipher.new('aes-256-gcm')
        cipher.decrypt
        cipher.key = encryption_key

        iv = data[0, 12]
        tag = data[12, 16]
        encrypted = data[28..]

        cipher.iv = iv
        cipher.auth_tag = tag

        cipher.update(encrypted) + cipher.final
      rescue OpenSSL::Cipher::CipherError, ArgumentError => e
        Rails.logger.error("Decryption failed: #{e.message}")
        nil
      end

      private

      def encryption_key
        key = ENV['ENCRYPTION_KEY'] || Rails.application.credentials.encryption_key
        # Fallback for development/test if not set
        key ||= 'development_secret_key_32_bytes!!' if Rails.env.development? || Rails.env.test?
        
        raise 'Encryption key not configured' if key.blank?

        # Ensure 32 bytes for AES-256
        if key.length >= 32
            key[0, 32]
        else
            Digest::SHA256.digest(key)
        end
      end
    end
  end
end


