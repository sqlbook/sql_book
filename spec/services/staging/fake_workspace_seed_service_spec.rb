# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Staging::FakeWorkspaceSeedService do
  describe '#call' do
    let!(:chris) do
      create(
        :user,
        email: 'chris.pattison@protonmail.com',
        first_name: 'Chris',
        last_name: 'Pattison'
      )
    end

    it 'creates fake workspaces with Chris attached in mixed roles and variable team sizes' do
      result = described_class.new(count: 4).call

      workspaces = Workspace.where("name LIKE 'Seed Workspace %'").order(:name)

      expect(result.created_workspaces.count).to eq(4)
      expect(workspaces.count).to eq(4)

      expect(workspaces.map { |workspace| workspace.members.accepted.count }).to eq([2, 3, 4, 5])
      expect(workspaces.map { |workspace| workspace.members.find_by(user: chris).role }).to eq(
        [Member::Roles::ADMIN, Member::Roles::USER, Member::Roles::READ_ONLY, Member::Roles::ADMIN]
      )

      expect(User.where("email LIKE '%@seed.sqlbook.test'").count).to eq(10)
      expect(workspaces.map(&:created_at).uniq.count).to eq(4)
    end
  end
end
