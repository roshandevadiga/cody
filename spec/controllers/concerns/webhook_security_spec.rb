require "rails_helper"

RSpec.describe WebhookSecurity, type: :controller do
  controller(ApplicationController) do
    include WebhookSecurity

    before_action :verify_webhook_signature!

    def create
      head :ok
    end
  end

  describe "#verify_webhook_signature!" do
    context "when no X-Hub-Signature header is present" do
      it "does not interrupt processing" do
        post :create
        expect(response.status).to eq(200)
      end
    end

    context "when the X-Hub-Signature header is present but the signature doesn't match" do
      it "returns 400 error" do
        request.headers["X-Hub-Signature"] = "bad_signature"
        post :create, params: { foo: "bar" }, as: :json
        expect(response.status).to eq(400)
      end
    end

    context "when the X-Hub-Signature is present and it matches" do
      it "passes on to the controller" do
        payload = { foo: "bar" }
        body = JSON.dump(payload)
        signature = "sha1=" + OpenSSL::HMAC.hexdigest(
          OpenSSL::Digest.new("sha1"),
          Rails.application.secrets.github_webhook_secret,
          body
        )
        request.headers["X-Hub-Signature"] = signature
        post :create, params: payload, as: :json
        expect(response.status).to eq(200)
      end
    end
  end
end
