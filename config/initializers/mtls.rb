# frozen_string_literal: true

# Insert mTLS client certificate extraction middleware.
# This must run before controllers so request.env["mtls.*"] is available.
Rails.application.config.middleware.use MtlsClientVerifier
