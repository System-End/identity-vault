# frozen_string_literal: true

class JwtIssuer
  class << self
    def issuer
      ENV.fetch("HCA_ISSUER") do
        if Rails.env.production?
          "https://auth.hackclub.com"
        elsif Rails.env.staging? || Rails.env.uat?
          "https://hca.dinosaurbbq.org"
        else
          "http://localhost:3000"
        end
      end
    end

    def short_token_exp
      (ENV["HCA_SHORT_TOKEN_EXP"] || 60).to_i
    end

    def issue_token(sub:, aud:, scope:, azp:)
      signing_key = SigningKey.current!
      now = Time.now.to_i
      jti = SecureRandom.uuid
      exp = now + short_token_exp

      payload = {
        iss: issuer, sub: sub, aud: aud, azp: azp,
        scope: scope, iat: now, nbf: now, exp: exp, jti: jti
      }

      token = JWT.encode(payload, signing_key.ed25519_signing_key, "EdDSA", { kid: signing_key.kid })
      { token: token, jti: jti, expires_at: Time.at(exp) }
    end
  end
end
