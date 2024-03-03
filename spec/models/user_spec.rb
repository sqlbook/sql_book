# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { create(:user, first_name: 'John', last_name: 'Densmore') }

  describe '#full_name' do
    it 'returns the full name' do
      expect(user.full_name).to eq('John Densmore')
    end
  end

  describe '#member_of?' do
    let(:workspace) { create(:workspace) }

    subject { user.member_of?(workspace:) }

    context 'when the user is not a member of the workspace' do
      it 'returns false' do
        expect(subject).to eq(false)
      end
    end

    context 'when the user is a member of the workspace' do
      before { create(:member, workspace:, user:) }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end
  end
end
