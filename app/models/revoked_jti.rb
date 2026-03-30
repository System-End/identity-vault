# frozen_string_literal: true

class RevokedJti < ApplicationRecord
  validates :jti, presence: true, uniqueness: true
  validates :revoked_at, presence: true

  def self.revoked?(jti)
    exists?(jti: jti)
  end
end
