# frozen_string_literal: true

require_relative "../../lib/middleware/mtls_client_verifier"

# Insert mTLS client certificate extraction middleware.
# This must run before controllers so request.env["mtls.*"] is available.
Rails.application.config.middleware.use MtlsClientVerifier
