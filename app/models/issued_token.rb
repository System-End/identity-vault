# frozen_string_literal: true

class IssuedToken < ApplicationRecord
  validates :jti, presence: true, uniqueness: true
  validates :sub, :aud, :azp, :scope, :expires_at, presence: true

  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :not_expired, -> { where("expires_at >= ?", Time.current) }

  def expired? = expires_at < Time.current
end
