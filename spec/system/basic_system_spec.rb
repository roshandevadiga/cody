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

  it "loads the page!", aggregate_failures: true do
    pull_requests = FactoryBot.create_list :pull_request, 5
    # binding.pry
    visit "/"
    expect(page).to have_text("Cody")
    # binding.pry
    pull_requests.each do |pr|
      expect(page).to have_text(pr.repository.full_name)
    end
  end
end
