# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Member, type: :model do
  describe '#owner?' do
    subject { instance.owner? }

    context 'when the member is an owner' do
      let(:instance) { Member.new(role: Member::Roles::OWNER) }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when the member is not an owner' do
      let(:instance) { Member.new(role: Member::Roles::ADMIN) }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#admin?' do
    subject { instance.admin? }

    context 'when the member is an admin' do
      let(:instance) { Member.new(role: Member::Roles::ADMIN) }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when the member is not an owner' do
      let(:instance) { Member.new(role: Member::Roles::READ_ONLY) }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#read_only?' do
    subject { instance.read_only? }

    context 'when the member is read only' do
      let(:instance) { Member.new(role: Member::Roles::READ_ONLY) }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when the member is not read only' do
      let(:instance) { Member.new(role: Member::Roles::USER) }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#user?' do
    subject { instance.user? }

    context 'when the member is a user' do
      let(:instance) { Member.new(role: Member::Roles::USER) }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when the member is not a user' do
      let(:instance) { Member.new(role: Member::Roles::READ_ONLY) }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#role_name' do
    subject { instance.role_name }

    context 'when the role is owner' do
      let(:instance) { Member.new(role: Member::Roles::OWNER) }

      it 'returns Owner' do
        expect(subject).to eq('Owner')
      end
    end

    context 'when the role is admin' do
      let(:instance) { Member.new(role: Member::Roles::ADMIN) }

      it 'returns Admin' do
        expect(subject).to eq('Admin')
      end
    end

    context 'when the role is user' do
      let(:instance) { Member.new(role: Member::Roles::USER) }

      it 'returns User' do
        expect(subject).to eq('User')
      end
    end

    context 'when the role is read_only' do
      let(:instance) { Member.new(role: Member::Roles::READ_ONLY) }

      it 'returns Read only' do
        expect(subject).to eq('Read only')
      end
    end
  end

  describe '#status_name' do
    subject { instance.status_name }

    context 'when the status is accepted' do
      let(:instance) { Member.new(status: Member::Status::ACCEPTED) }

      it 'returns Accepted' do
        expect(subject).to eq('Accepted')
      end
    end

    context 'when the status is pending' do
      let(:instance) { Member.new(status: Member::Status::PENDING) }

      it 'returns Pending' do
        expect(subject).to eq('Pending')
      end
    end
  end
end
