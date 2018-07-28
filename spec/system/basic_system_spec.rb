require "rails_helper"

RSpec.describe "Foobar", type: :system do
  let!(:user) { FactoryBot.create :user }

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
  end

  let!(:pull_requests) { FactoryBot.create_list :pull_request, 5 }

  it "loads the page!", aggregate_failures: true do
    visit "/"
    expect(page).to have_text("Cody")

    pull_requests.each do |pr|
      expect(page).to have_text(pr.repository.full_name)
    end
  end
end
