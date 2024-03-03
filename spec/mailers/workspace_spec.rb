# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkspaceMailer, type: :mailer do
  describe '#invite' do
    let(:member) { create(:member) }

    subject { described_class.invite(member:) }

    it 'renders the correct headers' do
      expect(subject.subject).to eq "You've been invited to join sql_book"
      expect(subject.to).to eq [member.user.email]
      expect(subject.from).to eq ['hello@sqlbook.com']
    end
  end
end
