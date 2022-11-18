require_relative 'json_serializable'

module ApplicationInsights::Channel::Contracts
  class User
    include JsonSerializable

    attr_accessor :account_id, :id, :auth_user_id

    attribute_mapping(
      account_id: 'ai.user.accountId',
      id: 'ai.user.id',
      auth_user_id: 'ai.user.authUserId'
    )
  end
end
