# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSourceMailer, type: :mailer do
  describe '#destroy' do
    let(:owner) { create(:user) }
    let(:deleted_by) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner:) }
    let(:data_source) { create(:data_source, workspace:) }

    subject { described_class.destroy(deleted_by:, data_source:, member: workspace.members.first) }

    it 'renders the correct headers' do
      expect(subject.subject).to eq "A data source has been delete from #{workspace.name}."
      expect(subject.to).to eq [owner.email]
      expect(subject.from).to eq ['noreply@sqlbook.com']
    end

    it 'includes the name of the user who deleted it' do
      expect(subject.body).to include("#{deleted_by.full_name} has deleted the data source")
    end
  end
end
