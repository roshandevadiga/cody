class Types::ReviewerStatusType < Types::BaseEnum
  description "The review status of a Reviewer"
  value("pending_approval", "Pending Approval")
  value("approved", "Approved")
end
