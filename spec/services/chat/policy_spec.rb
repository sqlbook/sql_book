# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::Policy, type: :service do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner:) }

  describe '#authorize' do
    it 'blocks explicitly disallowed namespaces' do
      policy = described_class.new(workspace:, actor: owner)
      decision = policy.authorize(action_type: 'query.run', payload: {})

      expect(decision.allowed).to be(false)
      expect(decision.reason_code).to eq('forbidden_action')
    end

    it 'allows an owner to delete a workspace' do
      policy = described_class.new(workspace:, actor: owner)
      decision = policy.authorize(action_type: 'workspace.delete', payload: {})

      expect(decision.allowed).to be(true)
    end

    it 'blocks an admin from deleting a workspace' do
      admin = create(:user)
      create(:member, workspace:, user: admin, role: Member::Roles::ADMIN)
      policy = described_class.new(workspace:, actor: admin)

      decision = policy.authorize(action_type: 'workspace.delete', payload: {})

      expect(decision.allowed).to be(false)
      expect(decision.reason_code).to eq('forbidden_role')
    end

    it 'blocks read-only members from inviting team members' do
      read_only = create(:user)
      create(:member, workspace:, user: read_only, role: Member::Roles::READ_ONLY)
      policy = described_class.new(workspace:, actor: read_only)

      decision = policy.authorize(
        action_type: 'member.invite',
        payload: { 'email' => 'new@example.com', 'role' => Member::Roles::USER }
      )

      expect(decision.allowed).to be(false)
      expect(decision.reason_code).to eq('forbidden_role')
    end

    it 'blocks user-role members from listing team members' do
      member_user = create(:user)
      create(:member, workspace:, user: member_user, role: Member::Roles::USER)
      policy = described_class.new(workspace:, actor: member_user)

      decision = policy.authorize(action_type: 'member.list', payload: {})

      expect(decision.allowed).to be(false)
      expect(decision.reason_code).to eq('forbidden_role')
    end

    it 'blocks actions when actor is not a member of the workspace' do
      outsider = create(:user)
      policy = described_class.new(workspace:, actor: outsider)

      decision = policy.authorize(action_type: 'member.list', payload: {})

      expect(decision.allowed).to be(false)
      expect(decision.reason_code).to eq('forbidden_scope')
    end

    it 'blocks role assignments above the actor role' do
      admin = create(:user)
      create(:member, workspace:, user: admin, role: Member::Roles::ADMIN)
      policy = described_class.new(workspace:, actor: admin)

      decision = policy.authorize(
        action_type: 'member.invite',
        payload: { 'email' => 'new@example.com', 'role' => Member::Roles::OWNER }
      )

      expect(decision.allowed).to be(false)
      expect(decision.reason_code).to eq('forbidden_role')
    end

    it 'blocks owner role updates through chat' do
      policy = described_class.new(workspace:, actor: owner)
      member = create(:member, workspace:, role: Member::Roles::USER)

      decision = policy.authorize(
        action_type: 'member.update_role',
        payload: { 'member_id' => member.id, 'role' => Member::Roles::OWNER }
      )

      expect(decision.allowed).to be(false)
      expect(decision.reason_code).to eq('validation_error')
    end

    it 'enforces outrank checks for member updates' do
      admin = create(:user)
      create(:member, workspace:, user: admin, role: Member::Roles::ADMIN)
      target_owner = create(:user)
      create(:member, workspace:, user: target_owner, role: Member::Roles::OWNER)
      policy = described_class.new(workspace:, actor: admin)

      decision = policy.authorize(
        action_type: 'member.update_role',
        payload: { 'email' => target_owner.email, 'role' => Member::Roles::USER }
      )

      expect(decision.allowed).to be(false)
      expect(decision.reason_code).to eq('forbidden_role')
    end

    it 'allows admins to manage data sources' do
      admin = create(:user)
      create(:member, workspace:, user: admin, role: Member::Roles::ADMIN)
      policy = described_class.new(workspace:, actor: admin)

      list_decision = policy.authorize(action_type: 'datasource.list', payload: {})
      validate_decision = policy.authorize(
        action_type: 'datasource.validate_connection',
        payload: { 'host' => 'db.example.com', 'database_name' => 'sales', 'username' => 'sqlbook', 'password' => 'secret' }
      )
      create_decision = policy.authorize(
        action_type: 'datasource.create',
        payload: {
          'name' => 'Sales DB',
          'host' => 'db.example.com',
          'database_name' => 'sales',
          'username' => 'sqlbook',
          'password' => 'secret',
          'selected_tables' => ['public.orders']
        }
      )

      expect(list_decision.allowed).to be(true)
      expect(validate_decision.allowed).to be(true)
      expect(create_decision.allowed).to be(true)
    end

    it 'blocks regular members from managing data sources' do
      member_user = create(:user)
      create(:member, workspace:, user: member_user, role: Member::Roles::USER)
      policy = described_class.new(workspace:, actor: member_user)

      decision = policy.authorize(action_type: 'datasource.create', payload: {})

      expect(decision.allowed).to be(false)
      expect(decision.reason_code).to eq('forbidden_role')
    end
  end
end
