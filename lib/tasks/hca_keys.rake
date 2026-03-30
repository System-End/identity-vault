# frozen_string_literal: true

namespace :hca do
  namespace :keys do
    desc "Generate a new Ed25519 signing key and activate it"
    task generate: :environment do
      key = SigningKey.generate_new!(activate: true)
      puts "Generated and activated signing key: kid=#{key.kid}"
      puts "Public JWK:"
      puts JSON.pretty_generate(key.public_jwk)
    end

    desc "Rotate: generate a new active key, deactivate the previous one"
    task rotate: :environment do
      old_key = SigningKey.current
      if old_key
        old_key.update!(active: false)
        puts "Deactivated previous key: kid=#{old_key.kid}"
      end

      new_key = SigningKey.generate_new!(activate: true)
      puts "Activated new signing key: kid=#{new_key.kid}"
      puts ""
      puts "Previous key (#{old_key&.kid || 'none'}) is now INACTIVE but still in JWKS."
      puts "It will be retired by RetireOldSigningKeysJob after the grace window."
      puts "To retire immediately: bin/rails hca:keys:retire[#{old_key&.kid}]"
    end

    desc "Retire a specific signing key (removes it from JWKS)"
    task :retire, [ :kid ] => :environment do |_t, args|
      kid = args[:kid]
      unless kid.present?
        puts "Usage: bin/rails hca:keys:retire[kid-value-here]"
        exit 1
      end

      key = SigningKey.find_by!(kid: kid)
      key.retire!
      puts "Retired signing key: kid=#{kid}"
    end

    desc "List all signing keys"
    task list: :environment do
      keys = SigningKey.order(created_at: :desc)
      if keys.empty?
        puts "No signing keys found. Run: bin/rails hca:keys:generate"
      else
        puts "%-40s %-8s %-25s %-25s" % %w[KID ACTIVE RETIRED CREATED]
        puts "-" * 100
        keys.each do |key|
          status = key.active? ? "YES" : "no"
          retired = key.retired? ? key.retired_at.iso8601 : "-"
          puts "%-40s %-8s %-25s %-25s" % [ key.kid, status, retired, key.created_at.iso8601 ]
        end
      end
    end
  end
end
