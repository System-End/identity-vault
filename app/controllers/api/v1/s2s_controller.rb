# frozen_string_literal: true

module API
  module V1
    class S2sController < ActionController::API
      before_action :authenticate_s2s!

      # GET /api/v1/s2s/identities/:id/address
      def address
        identity = Identity.find_by_public_id!(params[:id])
        addr = identity.primary_address

        Rails.logger.info "[S2S] address: program=#{@s2s_program.uid} identity=#{params[:id]}"

        render json: {
          address: addr ? {
            first_name: addr.first_name, last_name: addr.last_name,
            line_1: addr.line_1, line_2: addr.line_2,
            city: addr.city, state: addr.state,
            postal_code: addr.postal_code, country: addr.country
          } : nil
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "identity_not_found" }, status: :not_found
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
