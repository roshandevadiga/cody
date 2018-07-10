require "openssl"

module WebhookSecurity
  extend ActiveSupport::Concern

  private

  def verify_webhook_signature!
    unless valid_signature?
      head :bad_request
      return
    end
  end

  def valid_signature?
    signature = request.headers["X-Hub-Signature"]
    return true unless signature.present?

    request.body.rewind
    body = request.body.read
    request.body.rewind

    expected_signature = "sha1=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha1"),
      Rails.application.secrets.github_webhook_secret,
      body
    )

    ActiveSupport::SecurityUtils.secure_compare(
      signature,
      expected_signature
    )
  end
end
