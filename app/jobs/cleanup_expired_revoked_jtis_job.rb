# frozen_string_literal: true

class CleanupExpiredRevokedJtisJob < ApplicationJob
  queue_as :default

  def perform(retention_minutes: 5)
    count = RevokedJti.where("revoked_at < ?", retention_minutes.minutes.ago).delete_all
    Rails.logger.info "[Cleanup] Deleted #{count} revoked_jtis older than #{retention_minutes}m"
  end
end
