# frozen_string_literal: true

class CleanupExpiredIssuedTokensJob < ApplicationJob
  queue_as :default

  # Deletes issued_token audit records older than the retention period.
  def perform(retention_days: 90)
    cutoff = retention_days.days.ago
    deleted_count = IssuedToken.where("created_at < ?", cutoff).delete_all
    Rails.logger.info "[Cleanup] Deleted #{deleted_count} expired issued_tokens older than #{retention_days} days"
  end
end
