# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::QueryFollowUpMatcher do
  describe '.contextual_follow_up?' do
    let(:recent_query_reference) do
      {
        'sql' => 'SELECT id, first_name, last_name, email, created_at FROM public.users',
        'data_source_name' => 'Staging App DB'
      }
    end

    it 'treats column-removal refinement phrasing as a query follow-up' do
      text = 'Can we remove the terms version column, pending_email, and email_change_verification_token columns?'

      expect(
        described_class.contextual_follow_up?(text:, recent_query_reference:)
      ).to be(true)
    end

    it 'does not treat obvious non-query topic text as a query follow-up' do
      text = 'Can we remove that team member?'

      expect(
        described_class.contextual_follow_up?(text:, recent_query_reference:)
      ).to be(false)
    end
  end
end
