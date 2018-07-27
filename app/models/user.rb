require "jwt"

class User < ApplicationRecord
  validates :login, presence: true
  validates :uid, presence: true

  has_one :user_preference, inverse_of: :user
  has_many :api_keys

  ALLOWED_JWT_ALGORITHMS = %w(HS256 RS256).freeze

  USER_PREFERENCES = %i[
    send_new_reviews_summary
    send_new_reviews_summary?
  ].freeze

  # rubocop:disable Lint/AmbiguousOperator
  delegate *USER_PREFERENCES, to: :user_preference, allow_nil: true
  # rubocop:enable Lint/AmbiguousOperator

  def role
    ActiveSupport::StringInquirer.new(super)
  end

  def make_api_key
    api_key = self.api_keys.build
    api_key.password = SecureRandom.base58(24)
    api_key
  end

  def self.from_access_token(access_token)
    return unless access_token
    # First decode the token without verification to get the token's encryption
    # algorithm. The payload is discarded because it can't be trusted.
    _, header = JWT.decode(access_token, nil, false)
    alg = header["alg"]

    # Return unless the token's algorithm is one of the supported algorithms.
    # This prevents attackers from passing a token with algorithm set to "none".
    return unless ALLOWED_JWT_ALGORITHMS.include?(alg)

    # Now extract the payload according to the algorithm. Verification is
    # enabled and verification errors are caught and converted to nil. Assuming
    # verification of the token succeeds, then we can simply lookup the user by
    # the "sub" claim.
    begin
      case alg
      when "HS256"
        # HS256 tokens come from the /token/authenticate route and are used by
        # the React application.
        secret_key = Rails.application.secrets.jwt_secret_key
        payload, _ = JWT.decode(
          access_token,
          secret_key,
          true,
          algorithm: "HS256"
        )
        User.find_by(login: payload["sub"])
      when "RS256"
        # RS256 tokens are used by external clients authenticating with the
        # GraphQL API.
      end
    rescue JWT::VerificationError
      return
    end
  end

  def make_access_token
    payload = {
      sub: self.login,
      iat: Time.now.to_i
    }
    JWT.encode(payload, Rails.application.secrets.jwt_secret_key, "HS256")
  end
end
