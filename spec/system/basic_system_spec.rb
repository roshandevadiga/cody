require "rails_helper"

RSpec.describe "Pull Requests flow", type: :system do
  let!(:user) { FactoryBot.create :user }
  let!(:pull_requests) { FactoryBot.create_list :pull_request, 5 }

  before do
    mock_auth(
      :github,
      {
        uid: 4,
        info: {
          nickname: user.login,
          email: user.email,
          name: user.name
        }
      }
    )

    pr = pull_requests.first
    FactoryBot.create :reviewer, pull_request: pr, review_rule: nil
    2.times do |x|
      # These ones will have a review rule associated
      FactoryBot.create :reviewer, pull_request: pr
    end
  end

  it "allows drilling down to a single Pull Request", aggregate_failures: true do
    visit "/"
    expect(page).to have_text("Cody")

    pull_requests.each do |pr|
      expect(page).to have_text(pr.repository.full_name)
    end

    click_on pull_requests.first.repository.full_name

    pull_requests.first.repository.pull_requests.each do |pr|
      expect(page).to have_text("#{pull_requests.first.repository.full_name}##{pr.number}")
    end

    click_on "#{pull_requests.first.repository.full_name}##{pull_requests.first.number}"

    pull_requests.first.reviewers.each do |reviewer|
      expect(page).to have_content(reviewer.login)
      if reviewer.review_rule
        expect(page).to have_content(reviewer.review_rule.name)
      end
    end
  end
end
