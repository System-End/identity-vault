# frozen_string_literal: true

class RetireOldSigningKeysJob < ApplicationJob
  queue_as :default

  # Retires inactive (but not yet retired) signing keys older than the grace window.
  def perform(grace_window_hours: 1)
    cutoff = grace_window_hours.hours.ago

    keys_to_retire = SigningKey
      .where(active: false, retired_at: nil)
      .where("created_at < ?", cutoff)

    keys_to_retire.find_each do |key|
      key.retire!
      Rails.logger.info "[KeyRotation] Retired signing key kid=#{key.kid}"
    end
  end
end
