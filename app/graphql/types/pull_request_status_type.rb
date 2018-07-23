class Types::PullRequestStatusType < Types::BaseEnum
  description "The review status of a PullRequest"
  value("pending_review", "Pending Review")
  value("approved", "Approved")
end
