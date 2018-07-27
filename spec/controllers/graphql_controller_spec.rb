require "rails_helper"

RSpec.describe GraphqlController, type: :controller do
  describe "POST :execute" do
    context "with no authorization" do
      it "returns 401 Unauthorized" do
        post :execute
        expect(response.status).to eq(401)
      end
    end

    context "with authorization" do
      let(:user) { FactoryBot.create :user }
      let(:token) { user.make_access_token }

      context "provided in the Authorization header" do
        before do
          request.headers["Authorization"] = "Token #{token}"
        end

        it "is successful" do
          post :execute
          expect(response).to be_success
        end
      end

      context "provided in the session" do
        before do
          session[:access_token] = token
        end

        it "is successful" do
          post :execute
          expect(response).to be_success
        end
      end
    end
  end
end
