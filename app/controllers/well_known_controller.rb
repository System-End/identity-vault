# frozen_string_literal: true

class WellKnownController < ActionController::API
  def jwks
    keys = SigningKey.not_retired.order(created_at: :desc).pluck(:public_jwk)
    response.headers["Cache-Control"] = "public, max-age=300"
    render json: { keys: keys }
  rescue => e
    Rails.logger.error "[JWKS] #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
    response.headers["Retry-After"] = "30"
    render json: { error: "jwks_unavailable" }, status: :service_unavailable
  end
end
