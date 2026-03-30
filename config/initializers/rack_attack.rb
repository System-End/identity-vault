class Rack::Attack
  throttle("logins/email", limit: 5, period: 5.minutes) do |req|
    if req.path == "/login" && req.post?
      req.params["email"]&.to_s&.downcase&.presence
    end
  end

  throttle("logins/ip", limit: 10, period: 5.minutes) do |req|
    if req.path == "/login" && req.post?
      req.ip
    end
  end

  throttle("email_verify/attempt", limit: 10, period: 5.minutes) do |req|
    if req.path.match?(%r{^/login/(.+)/verify$}) && req.post?
      $1
    end
  end

  throttle("totp_login/attempt", limit: 5, period: 5.minutes) do |req|
    if req.path.match?(%r{^/login/(.+)/totp$}) && req.post?
      $1
    end
  end

  throttle("backup_code_login/attempt", limit: 5, period: 5.minutes) do |req|
    if req.path.match?(%r{^/login/(.+)/backup_code$}) && req.post?
      $1
    end
  end

  throttle("login_verify/ip", limit: 20, period: 5.minutes) do |req|
    if req.path.match?(%r{^/login/.+/(verify|totp|backup_code)$}) && req.post?
      req.ip
    end
  end

  throttle("email_change/ip", limit: 3, period: 1.hour) do |req|
    if req.path == "/email_changes" && req.post?
      req.ip
    end
  end

  throttle("email_change_verify/ip", limit: 10, period: 5.minutes) do |req|
    if req.path.match?(%r{^/email_changes/verify/(old|new)$}) && %w[GET POST].include?(req.request_method)
      req.ip
    end
  end

  # --- Token Exchange / S2S / JWKS ---

  throttle("token_exchange/client", limit: 10, period: 1.minute) do |req|
    if req.path == "/api/v1/token/exchange" && req.post?
      ActionController::HttpAuthentication::Basic.user_name_and_password(req).first rescue req.ip
    end
  end

  throttle("s2s/client", limit: 30, period: 1.minute) do |req|
    if req.path.start_with?("/api/v1/s2s/") && req.get?
      ActionController::HttpAuthentication::Basic.user_name_and_password(req).first rescue req.ip
    end
  end

  throttle("jwks/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path == "/.well-known/jwks.json" && req.get?
  end

  throttle("revocations/client", limit: 20, period: 1.minute) do |req|
    if req.path.start_with?("/api/v1/revocations/")
      ActionController::HttpAuthentication::Basic.user_name_and_password(req).first rescue req.ip
    end
  end

  self.throttled_responder = lambda do |env|
    request = Rack::Request.new(env)

    if request.path.start_with?("/api/") || request.path == "/.well-known/jwks.json"
      headers = { "Content-Type" => "application/json", "Retry-After" => "60" }
      body = '{"error":"rate_limited","retry_after":60}'
      [ 429, headers, [ body ] ]
    else
      headers = { "Content-Type" => "text/html", "Retry-After" => "300" }
      [ 429, headers, [ "slow your roll!" ] ]
    end
  end
end
