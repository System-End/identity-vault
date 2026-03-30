# frozen_string_literal: true

class SigningKey < ApplicationRecord
  has_encrypted :private_key_seed

  scope :active_keys, -> { where(active: true, retired_at: nil) }
  scope :not_retired, -> { where(retired_at: nil) }

  validates :kid, presence: true, uniqueness: true
  validates :public_jwk, presence: true

  def self.current!
    active_keys.order(created_at: :desc).first!
  rescue ActiveRecord::RecordNotFound
    raise "No active signing key found. Run: bin/rails hca:keys:generate"
  end

  def self.current
    active_keys.order(created_at: :desc).first
  end

  def self.generate_new!(activate: false)
    require "ed25519"

    signing_key = Ed25519::SigningKey.generate
    verify_key = signing_key.verify_key
    kid = "hca-ed25519-#{SecureRandom.hex(8)}"

    jwk = {
      kty: "OKP",
      crv: "Ed25519",
      x: Base64.urlsafe_encode64(verify_key.to_bytes, padding: false),
      kid: kid,
      use: "sig",
      alg: "EdDSA"
    }

    create!(
      kid: kid,
      private_key_seed: Base64.strict_encode64(signing_key.seed),
      public_jwk: jwk,
      active: activate
    )
  end

  def ed25519_signing_key
    require "ed25519"
    Ed25519::SigningKey.new(Base64.strict_decode64(private_key_seed))
  end

  def ed25519_verify_key
    require "ed25519"
    raw_pub = Base64.urlsafe_decode64(public_jwk["x"] || public_jwk[:x])
    Ed25519::VerifyKey.new(raw_pub)
  end

  def retire!
    update!(retired_at: Time.current, active: false)
  end

  def retired? = retired_at.present?
end
