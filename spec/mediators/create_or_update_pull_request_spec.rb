require 'rails_helper'

RSpec.describe CreateOrUpdatePullRequest, type: :model do
  describe "#perform" do
    let(:payload) { json_fixture("pull_request", body: body, number: 9876)["pull_request"] }
    let(:repo_full_name) { payload["base"]["repo"]["full_name"] }
    let(:head_sha) { payload["head"]["sha"] }
    let!(:repo) { FactoryBot.create :repository, owner: repo_full_name.split("/", 2)[0], name: repo_full_name.split("/", 2)[1] }

    context "linking to a parent PR" do
      let(:body) do
        "Reviewed in #1234"
      end

      let!(:parent_pr) { FactoryBot.create :pull_request, status: "pending_review", number: 1234, repository: repo }

      before do
        pr_9876 = json_fixture("pr", number: 9876, head_sha: head_sha)
        stub_request(:get, %r{https://api.github.com/repos/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/pulls/9876}).to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: pr_9876.to_json
        )

        pr_1234 = json_fixture("pr", number: 1234)
        stub_request(:get, %r{https://api.github.com/repos/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/pulls/1234}).to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: pr_1234.to_json
        )

        stub_request(:post, "https://api.github.com/repos/#{repo_full_name}/statuses/#{head_sha}")
      end

      it "links the PR to the parent" do
        CreateOrUpdatePullRequest.new.perform(payload)
        expect(PullRequest.find_by(number: 9876).parent_pull_request).to eq(parent_pr)
      end

      it "posts the commit status" do
        CreateOrUpdatePullRequest.new.perform(payload)
        expect(WebMock).to have_requested(
          :post,
          "https://api.github.com/repos/#{repo_full_name}/statuses/#{head_sha}"
        ).with { |request|
            json_body = JSON.load(request.body)
            json_body["description"] == "Review is delegated to #1234"
          }
      end

      context 'PR is referenced but not intended be linked' do
        let(:body) do
          " The previous version of this was reviewed in #1234"
        end

        it 'does not link the PR with other one' do
          CreateOrUpdatePullRequest.new.perform(payload)
          expect(PullRequest.find_by(number: 9876).parent_pull_request).to be_nil
        end
      end

      context "and the link is removed later" do
        let!(:pr) { FactoryBot.create :pull_request, status: "pending_review", number: 9876, repository: repo, parent_pull_request: parent_pr }
        let(:body) { "" }

        before do
          stub_request(:patch, "https://api.github.com/repos/baxterthehacker/public-repo/issues/9876")
            .to_return(status: 200, body: "", headers: {})
        end

        it "removes the parent PR association" do
          expect {
            CreateOrUpdatePullRequest.new.perform(payload)
          }.to change {
            pr.reload.parent_pull_request
          }.from(parent_pr).to(nil)
        end
      end
    end

    context "synchronizing the peer review list" do
      let!(:pull_request) { FactoryBot.create :pull_request, number: 9876, repository: repo }
      let!(:gen_reviewers) { FactoryBot.create_list :reviewer, 2, pull_request: pull_request}

      let(:r1_name) { SecureRandom.hex }
      let!(:r1) { FactoryBot.create :reviewer, login: r1_name, review_rule: nil, pull_request: pull_request }

      let(:r2_name) { SecureRandom.hex }
      let!(:r2) { FactoryBot.create :reviewer, login: r2_name, review_rule: nil, pull_request: pull_request }

      let!(:r3) { FactoryBot.create :reviewer, review_rule: nil, pull_request: pull_request }

      let!(:body) do
        "- [ ] @#{r1_name}\\n- [ ] @#{r2_name}"
      end

      before do
        allow(ApplyReviewRules).to receive(:new).and_return(double(perform: true))

        stub_request(:get, %r{https://api.github.com/repos/baxterthehacker/public-repo/collaborators/.*})
          .to_return(status: 204, body: "", headers: {})

        pr_9876 = json_fixture("pr", number: 9876, head_sha: head_sha)
        stub_request(:get, "https://api.github.com/repos/baxterthehacker/public-repo/pulls/9876").to_return(
          status: 200,
          body: pr_9876.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

        stub_request(:post, %r{https://api.github.com/repos/baxterthehacker/public-repo/statuses/.*})
          .to_return(status: 200, body: "", headers: {})
        stub_request(:patch, "https://api.github.com/repos/baxterthehacker/public-repo/issues/9876")
          .to_return(status: 200, body: "", headers: {})
      end

      it "removes peer reviewers who were deleted manually but leaves generated reviewers" do
        CreateOrUpdatePullRequest.new.perform(payload)
        expected_reviewers = [
          r1_name,
          r2_name,
          *gen_reviewers.map(&:login)
        ]
        expect(pull_request.reviewers.map(&:login)).to contain_exactly(*expected_reviewers)
      end
    end
  end
end
