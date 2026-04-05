# frozen_string_literal: true

class QueryGroupMembership < ApplicationRecord
  belongs_to :query
  belongs_to :query_group

  validates :query_id,
            uniqueness: {
              scope: :query_group_id
            }

  after_destroy_commit :destroy_group_if_orphaned

  private

  def destroy_group_if_orphaned
    group = QueryGroup.find_by(id: query_group_id)
    return unless group
    return if group.query_group_memberships.exists?

    group.destroy!
  end
end
