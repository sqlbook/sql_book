# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountDeletionService, type: :service do
  describe '#call' do
    let(:mail_delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

    before do
      allow(AccountMailer).to receive(:account_deletion_confirmed).and_return(mail_delivery)
      allow(WorkspaceMailer).to receive(:workspace_deleted).and_return(mail_delivery)
      allow(WorkspaceMailer).to receive(:workspace_owner_transferred).and_return(mail_delivery)
    end

    context 'when ownership is transferred to an accepted member' do
      let(:user) { create(:user, first_name: 'Chris', last_name: 'Pattison', email: 'owner@sitelabs.ai') }
      let(:new_owner_user) { create(:user, first_name: 'Lewis', last_name: 'Monteith') }
      let(:workspace) { create(:workspace, name: 'Acme Inc') }
      let!(:owner_membership) { create(:member, user:, workspace:, role: Member::Roles::OWNER) }
      let!(:new_owner_membership) { create(:member, user: new_owner_user, workspace:, role: Member::Roles::ADMIN) }

      it 'promotes selected member to owner, deletes account, and sends notifications' do
        result = described_class.new(
          user:,
          workspace_actions: { workspace.id.to_s => new_owner_membership.id.to_s }
        ).call

        expect(result.success?).to be(true)
        expect(User.find_by(id: user.id)).to be_nil
        expect(new_owner_membership.reload.role).to eq(Member::Roles::OWNER)
        expect(Workspace.find_by(id: workspace.id)).to be_present

        expect(AccountMailer).to have_received(:account_deletion_confirmed).with(user_email: 'owner@sitelabs.ai')
        expect(WorkspaceMailer).to have_received(:workspace_owner_transferred).with(
          new_owner: new_owner_user,
          workspace:,
          previous_owner_name: 'Chris Pattison'
        )
        expect(WorkspaceMailer).not_to have_received(:workspace_deleted)
      end
    end

    context 'when workspace deletion is selected' do
      let(:user) { create(:user, first_name: 'Chris', last_name: 'Pattison', email: 'owner@sitelabs.ai') }
      let(:member_user) { create(:user, first_name: 'Bob', last_name: 'Monkfish', email: 'member@sitelabs.ai') }
      let(:workspace) { create(:workspace, name: 'Bananas Ltd') }
      let!(:owner_membership) { create(:member, user:, workspace:, role: Member::Roles::OWNER) }
      let!(:member_membership) { create(:member, user: member_user, workspace:, role: Member::Roles::USER) }

      it 'deletes the workspace and informs remaining members' do
        result = described_class.new(
          user:,
          workspace_actions: { workspace.id.to_s => AccountDeletionService::DELETE_WORKSPACE_ACTION }
        ).call

        expect(result.success?).to be(true)
        expect(User.find_by(id: user.id)).to be_nil
        expect(Workspace.find_by(id: workspace.id)).to be_nil

        expect(AccountMailer).to have_received(:account_deletion_confirmed).with(user_email: 'owner@sitelabs.ai')
        expect(WorkspaceMailer).to have_received(:workspace_deleted).with(
          user: member_user,
          workspace_name: 'Bananas Ltd',
          workspace_owner_name: 'Chris Pattison'
        )
        expect(WorkspaceMailer).not_to have_received(:workspace_owner_transferred)
      end
    end

    context 'when required workspace actions are missing' do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, name: 'Alphabet Inc') }
      let!(:owner_membership) { create(:member, user:, workspace:, role: Member::Roles::OWNER) }
      let!(:eligible_member) { create(:member, workspace:, role: Member::Roles::ADMIN) }

      it 'fails with unresolved workspace actions and keeps data unchanged' do
        result = described_class.new(user:, workspace_actions: {}).call

        expect(result.success?).to be(false)
        expect(result.error_key).to eq(:account_delete_unresolved_workspaces)
        expect(User.find_by(id: user.id)).to be_present
        expect(Workspace.find_by(id: workspace.id)).to be_present

        expect(AccountMailer).not_to have_received(:account_deletion_confirmed)
        expect(WorkspaceMailer).not_to have_received(:workspace_owner_transferred)
        expect(WorkspaceMailer).not_to have_received(:workspace_deleted)
      end
    end

    context 'when owned workspace has no other accepted members' do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, name: 'Solo Workspace') }
      let!(:owner_membership) { create(:member, user:, workspace:, role: Member::Roles::OWNER) }
      let!(:pending_member) { create(:member, workspace:, role: Member::Roles::USER, status: Member::Status::PENDING) }

      it 'deletes the workspace without requiring transfer selection' do
        result = described_class.new(user:, workspace_actions: {}).call

        expect(result.success?).to be(true)
        expect(User.find_by(id: user.id)).to be_nil
        expect(Workspace.find_by(id: workspace.id)).to be_nil

        expect(AccountMailer).to have_received(:account_deletion_confirmed).with(user_email: user.email)
      end
    end
  end
end
