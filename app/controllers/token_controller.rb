class TokenController < ApplicationController
  include ActionController::HttpAuthentication::Token
  include ActionController::HttpAuthentication::Token::ControllerMethods

  def authenticate
    authenticate_or_request_with_http_token do |token, options|
      api_key = ApiKey.find_by(id: options[:id])
      if api_key.authenticate(token)
        session[:access_token] = api_key.user.make_access_token
      else
        head :unauthorized
        return
      end
    end
  end
end
