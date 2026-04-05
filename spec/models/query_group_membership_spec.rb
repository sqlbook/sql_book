# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QueryGroupMembership, type: :model do
  describe 'orphan cleanup' do
    it 'destroys the group when the final membership is removed' do
      query = create(:query)
      group = create(:query_group, workspace: query.data_source.workspace)
      membership = create(:query_group_membership, query:, query_group: group)

      expect { membership.destroy! }
        .to change(QueryGroupMembership, :count).by(-1)
        .and change(QueryGroup, :count).by(-1)
    end

    it 'keeps the group when other memberships still exist' do
      query = create(:query)
      other_query = create(:query, data_source: create(:data_source, workspace: query.data_source.workspace))
      group = create(:query_group, workspace: query.data_source.workspace)
      membership = create(:query_group_membership, query:, query_group: group)
      create(:query_group_membership, query: other_query, query_group: group)

      expect { membership.destroy! }
        .to change(QueryGroupMembership, :count).by(-1)
        .and change(QueryGroup, :count).by(0)
    end
  end
end
