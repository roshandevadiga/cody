class GraphqlController < ApplicationController
  include ActionController::HttpAuthentication::Token

  protect_from_forgery with: :null_session
  before_action :require_authentication!

  def execute
    variables = ensure_hash(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      # Query context goes here, for example:
      current_user: current_user
    }
    result = CodySchema.execute(
      query,
      variables: variables,
      context: context,
      operation_name: operation_name
    )
    render json: result
  end

  private

  # Handle form data, JSON body, or a blank value
  def ensure_hash(ambiguous_param)
    case ambiguous_param
    when String
      if ambiguous_param.present?
        ensure_hash(JSON.parse(ambiguous_param))
      else
        {}
      end
    when Hash, ActionController::Parameters
      ambiguous_param
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{ambiguous_param}"
    end
  end

  def require_authentication!
    unless current_user.present?
      head :unauthorized
      return
    end
  end

  def current_user
    access_token = access_token_from_header || access_token_from_session
    Current.user ||= User.from_access_token(access_token)
  end

  # The /token/authenticate route stores tokens in the session after it confirms
  # the user's identity.
  def access_token_from_session
    session[:access_token].presence
  end

  # External clients use the Authorization header to pass access tokens.
  def access_token_from_header
    token_and_options(request)&.first&.presence
  end
end
