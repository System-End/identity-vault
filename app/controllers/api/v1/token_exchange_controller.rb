# frozen_string_literal: true

module API
  module V1
    class TokenExchangeController < ActionController::API
      # POST /api/v1/token/exchange
      def create
        program = authenticate_client!
        return unless program
        return render json: { error: "mtls_mismatch" }, status: :forbidden unless verify_mtls!(program)

        user_token_value = params[:user_token]
        return render json: { error: "missing_user_token" }, status: :bad_request unless user_token_value.present?

        oauth_token = OAuthToken.accessible.find_by(token: user_token_value)
        return render json: { error: "invalid_user_token" }, status: :unauthorized unless oauth_token

        identity = oauth_token.resource_owner
        return render json: { error: "invalid_user_token" }, status: :unauthorized unless identity

        aud = params[:aud].to_s.strip
        return render json: { error: "invalid_audience" }, status: :bad_request unless aud.present? && allowed_audiences.include?(aud)

        if program.allowed_audiences.present? && !program.allowed_audiences.include?(aud)
          return render json: { error: "audience_not_permitted" }, status: :forbidden
        end

        requested_scope = params[:scope].to_s.strip
        return render json: { error: "invalid_scope" }, status: :bad_request unless requested_scope.present? && OAuthScope.known?(requested_scope)
        return render json: { error: "scope_not_consented" }, status: :forbidden unless oauth_token.scopes.include?(requested_scope)

        result = JwtIssuer.issue_token(sub: identity.public_id, aud: aud, scope: requested_scope, azp: program.uid)

        IssuedToken.create!(
          jti: result[:jti], sub: identity.public_id, aud: aud,
          azp: program.uid, scope: requested_scope, expires_at: result[:expires_at]
        )

        Rails.logger.info "[TokenExchange] jti=#{result[:jti]} sub=#{identity.public_id} aud=#{aud} azp=#{program.uid} scope=#{requested_scope}"

        response.headers["Cache-Control"] = "no-store"
        response.headers["Pragma"] = "no-cache"

        render json: {
          access_token: result[:token], token_type: "Bearer", expires_in: JwtIssuer.short_token_exp
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "signing_key_unavailable" }, status: :service_unavailable
      rescue => e
        Rails.logger.error "[TokenExchange] #{e.class}: #{e.message}"
        Sentry.capture_exception(e) if defined?(Sentry)
        render json: { error: "internal_error" }, status: :internal_server_error
      end

      private

      def allowed_audiences
        @allowed_audiences ||= ENV.fetch("HCA_ALLOWED_AUDIENCES", "https://mail.hackclub.com").split(",").map(&:strip)
      end

      def authenticate_client!
        client_id, client_secret = ActionController::HttpAuthentication::Basic.user_name_and_password(request)

        unless client_id.present? && client_secret.present?
          render json: { error: err("missing_credentials") }, status: :unauthorized
          return nil
        end

        program = Program.find_by(uid: client_id)
        unless program && ActiveSupport::SecurityUtils.secure_compare(program.secret, client_secret)
          render json: { error: err("invalid_credentials") }, status: :unauthorized
          return nil
        end

        program
      rescue => e
        Rails.logger.error "[TokenExchange] Client auth: #{e.message}"
        render json: { error: err("invalid_credentials") }, status: :unauthorized
        nil
      end

      def verify_mtls!(program)
        fingerprint = request.env["mtls.client_fingerprint"]
        unless fingerprint.present?
          render json: { error: err("mtls_required") }, status: :forbidden
          return false
        end

        if request.env["mtls.cert_expired"]
          render json: { error: err("mtls_cert_expired") }, status: :forbidden
          return false
        end

        unless program.client_cert_fingerprint.present?
          render json: { error: "mtls_not_configured" }, status: :forbidden
          return false
        end

        ActiveSupport::SecurityUtils.secure_compare(
          fingerprint.downcase.delete(":"),
          program.client_cert_fingerprint.downcase.delete(":")
        )
      end

      # generic error in prod to avoid leaking internals
      def err(code) = Rails.env.production? ? "authentication_failed" : code
    end
  end
end
