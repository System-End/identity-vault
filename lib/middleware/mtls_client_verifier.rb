# Extracts mTLS client cert from reverse proxy headers (Traefik / nginx).
# Sets env["mtls.client_fingerprint"], env["mtls.client_subject"], env["mtls.client_cert"].
# Does NOT reject requests -- controllers decide what to enforce.
class MtlsClientVerifier
  HEADERS = %w[HTTP_X_FORWARDED_TLS_CLIENT_CERT HTTP_X_SSL_CERT].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    cert_pem = HEADERS.lazy.filter_map { |h| env[h].presence }.first

    if cert_pem
      begin
        decoded_pem = CGI.unescape(cert_pem)
        cert = OpenSSL::X509::Certificate.new(decoded_pem)

        env["mtls.client_fingerprint"] = OpenSSL::Digest::SHA256.hexdigest(cert.to_der).scan(/../).join(":").upcase
        env["mtls.client_subject"] = cert.subject.to_s
        env["mtls.client_cert"] = cert
        env["mtls.cert_expired"] = true if cert.not_after < Time.now
      rescue OpenSSL::X509::CertificateError => e
        Rails.logger.warn "[mTLS] Bad client cert: #{e.message}"
        env["mtls.error"] = e.message
      end
    end

    @app.call(env)
  end
end
