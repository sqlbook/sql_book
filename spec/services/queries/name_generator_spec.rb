# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::NameGenerator do
  let(:workspace) { create(:workspace_with_owner) }
  let(:data_source) { create(:data_source, :postgres, workspace:, name: 'Staging App DB') }

  describe '.generate' do
    it 'includes an ilike filter in count query names' do
      sql = <<~SQL.squish
        SELECT COUNT(*) AS user_count
        FROM public.users
        WHERE first_name ILIKE '%i%';
      SQL

      name = described_class.generate(
        question: 'What about the letter i?',
        sql:,
        data_source:
      )

      expect(name).to eq("User count with 'i' in first name")
    end

    it 'includes an ilike filter in user list names' do
      sql = <<~SQL.squish
        SELECT first_name, last_name, email
        FROM public.users
        WHERE last_name ILIKE '%i%';
      SQL

      name = described_class.generate(
        question: 'List the users with i in their last name',
        sql:,
        data_source:
      )

      expect(name).to eq("Users with 'i' in last name")
    end
  end
end
