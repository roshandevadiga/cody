# encoding: utf-8

require 'rails_helper'

RSpec.describe ReceiveIssueCommentEvent do
  let!(:pr) { FactoryBot.create :pull_request, status: "pending_review" }

  let(:reviewer) { "aergonaut" }

  let(:payload) do
    json_fixture("issue_comment", number: pr.number, sender: sender, body: comment, name: pr.repository.name, owner: pr.repository.owner)
  end

  let(:job) { ReceiveIssueCommentEvent.new }

  let(:sender) { reviewer }
  let!(:review) { FactoryBot.create(:reviewer, login: reviewer, pull_request: pr) }

  describe "#perform" do
    before do
      stub_request(:post, %r(https?://api.github.com/repos/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/statuses/[0-9abcdef]{40}))
      stub_request(:get, %r(https?://api.github.com/repos/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/pulls/\d+)).to_return(
        body: JSON.dump(pr_response_body),
        status: 200,
        headers: { "Content-Type" => "application/json" }
      )
      stub_request(:patch, %r{https?://api.github.com/repos/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/issues/\d+})
    end

    subject { job.perform(payload) }

    context "when submitting an approval" do
      let(:comment) { "lgtm" }

      let(:pr_response_body) { json_fixture("pr") }

      context "when the commenter is a reviewer" do
        context "and they approve" do
          it "moves them into the completed_reviews list" do
            subject
            pr.reload
            expect(pr.reviewers.pending_review.map(&:login)).to_not include(reviewer)
            expect(pr.reviewers.completed_review.map(&:login)).to include(sender)
          end

          context "and they are the last approver" do
            it "updates the status on GitHub" do
              subject
              expect(WebMock).to have_requested(:post, %r(https?://api.github.com/repos/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/statuses/[0-9abcdef]{40}))
            end

            it "marks the PR as approved" do
              subject
              expect(pr.reload.status).to eq("approved")
            end
          end

          context "and they approve with a literal emoji" do
            let(:comment) { "👍" }

            it "moves them into the completed_reviews list" do
              subject
              pr.reload
              expect(pr.reviewers.pending_review.map(&:login)).to_not include(reviewer)
              expect(pr.reviewers.completed_review.map(&:login)).to include(sender)
            end
          end

          context "and they were in the reivew list more than once" do
            before do
              review.status = "approved"
              review.save!
            end

            let!(:second_review) { FactoryBot.create(:reviewer, login: reviewer, pull_request: pr) }

            it "approves the pending_review review" do
              subject
              second_review.reload
              expect(second_review.status).to eq("approved")
            end
          end
        end
      end
    end
  end

  describe "#comment_replace" do
    let(:comment) { "cody replace foo=BrentW bar=mrpasquini" }

    let(:rule) { FactoryBot.create :review_rule, short_code: "foo", reviewer: acceptable_reviewer }

    before do
      stub_request(:get, %r(https?://api.github.com/repos/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/pulls/\d+)).to_return(
        body: JSON.dump(json_fixture("pr")),
        status: 200,
        headers: { "Content-Type" => "application/json" }
      )
      stub_request(:patch, %r{https?://api.github.com/repos/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/pulls/\d+})
      stub_request(:patch, %r{https?://api.github.com/repos/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/issues/\d+})

      FactoryBot.create :reviewer, review_rule: rule, pull_request: pr, login: "aergonaut"
    end

    context "when BrentW is a possible reviewer for the rule" do
      let(:acceptable_reviewer) { "BrentW" }

      it "replaces aergonaut with BrentW" do
        foo_reviewer = pr.reviewers.find_by(review_rule_id: rule.id)
        expect { job.perform(payload) }.to change { foo_reviewer.reload.login }.from("aergonaut").to("BrentW")
      end
    end

    context "when BrentW is not a possible reviewer for the rule" do
      let(:acceptable_reviewer) { "octocat" }

      it "does not change the reviewer" do
        foo_reviewer = pr.reviewers.find_by(review_rule_id: rule.id)
        expect { job.perform(payload) }.to_not change { foo_reviewer.reload.login }
      end
    end

    context "when the reviewer is specified with an @ sign" do
      let(:comment) { "cody replace foo=@BrentW" }
      let(:acceptable_reviewer) { "BrentW" }

      it "replaces aergonaut with BrentW" do
        foo_reviewer = pr.reviewers.find_by(review_rule_id: rule.id)
        expect { job.perform(payload) }.to change { foo_reviewer.reload.login }.from("aergonaut").to("BrentW")
      end
    end

    context "when the reviewer is specified with a space and an @ sign" do
      let(:comment) { "cody replace foo= @BrentW" }
      let(:acceptable_reviewer) { "BrentW" }

      it "replaces aergonaut with BrentW" do
        foo_reviewer = pr.reviewers.find_by(review_rule_id: rule.id)
        expect { job.perform(payload) }.to change { foo_reviewer.reload.login }.from("aergonaut").to("BrentW")
      end
    end
  end

  describe "#comment_replace_me" do
    let(:comment) { "cody replace me!" }

    let(:rule) { FactoryBot.create :review_rule, short_code: "foo", reviewer: acceptable_reviewer }

    before do
      stub_request(:get, %r(https?://api.github.com/repos/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/pulls/\d+)).to_return(
        body: JSON.dump(json_fixture("pr")),
        status: 200,
        headers: { "Content-Type" => "application/json" }
      )
      stub_request(:patch, %r{https?://api.github.com/repos/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/pulls/\d+})
      stub_request(:patch, %r{https?://api.github.com/repos/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/issues/\d+})

      FactoryBot.create :reviewer, review_rule: rule, pull_request: pr, login: "aergonaut"
    end

    context "when mrpasquini is a possible reviewer for the rule" do
      let(:acceptable_reviewer) { "mrpasquini" }

      it "replaces aergonaut with mrpasquini" do
        foo_reviewer = pr.reviewers.find_by(review_rule_id: rule.id)
        expect { job.perform(payload) }.to change { foo_reviewer.reload.login }.from("aergonaut").to("mrpasquini")
      end
    end

    context "when there is no other possible reviewer for the rule" do
      let(:acceptable_reviewer) { "aergonaut" }

      it "does not replace aergonaut" do
        foo_reviewer = pr.reviewers.find_by(review_rule_id: rule.id)
        expect { job.perform(payload) }.to_not change { foo_reviewer.reload.login }
      end
    end
  end
end
