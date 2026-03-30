# frozen_string_literal: true

module API
  module V1
    class RevocationsController < ActionController::API
      before_action :authenticate_s2s!

      # POST /api/v1/revocations/jti
      def create_jti
        jti = params[:jti]
        reason = params[:reason]
        revoked_by = params[:revoked_by] || @s2s_program&.name || "system"

        return render json: { error: "missing_jti" }, status: :bad_request unless jti.present?
        return render json: { error: "reason_too_long" }, status: :bad_request if reason.present? && reason.length > 500

        revoked = RevokedJti.find_or_initialize_by(jti: jti)
        if revoked.new_record?
          revoked.assign_attributes(revoked_at: Time.current, revoked_by: revoked_by, reason: reason)
          revoked.save!
          render json: { revoked: true, jti: jti }, status: :created
        else
          render json: { revoked: true, jti: jti, message: "already_revoked" }
        end
      end

      # GET /api/v1/revocations/jtis?since=2026-03-28T00:00:00Z
      def index_jtis
        since = params[:since] ? Time.parse(params[:since]) : 24.hours.ago
        jtis = RevokedJti.where("revoked_at >= ?", since).order(revoked_at: :desc).pluck(:jti)
        render json: { jtis: jtis, since: since.iso8601 }
      end

      private

      def authenticate_s2s!
        fingerprint = request.env["mtls.client_fingerprint"]
        return render json: { error: "mtls_required" }, status: :forbidden unless fingerprint.present?
        return render json: { error: "mtls_cert_expired" }, status: :forbidden if request.env["mtls.cert_expired"]

        client_id, client_secret = ActionController::HttpAuthentication::Basic.user_name_and_password(request)
        return render json: { error: "missing_credentials" }, status: :unauthorized unless client_id.present? && client_secret.present?

        @s2s_program = Program.find_by(uid: client_id)
        return render json: { error: "invalid_credentials" }, status: :unauthorized unless @s2s_program && ActiveSupport::SecurityUtils.secure_compare(@s2s_program.secret, client_secret)
        return render json: { error: "not_s2s_client" }, status: :forbidden unless @s2s_program.client_cert_fingerprint.present?

        unless ActiveSupport::SecurityUtils.secure_compare(
          fingerprint.downcase.delete(":"),
          @s2s_program.client_cert_fingerprint.downcase.delete(":")
        )
          render json: { error: "mtls_mismatch" }, status: :forbidden
        end
      end
    end
  end
end
