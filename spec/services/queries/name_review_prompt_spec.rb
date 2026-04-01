# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::NameReviewPrompt, type: :service do
  let(:actor) { build_stubbed(:user, preferred_locale: :en) }
  let(:workspace) { build_stubbed(:workspace, name: 'Orange Inc') }
  let(:data_source) { build_stubbed(:data_source, workspace:, name: 'Staging App DB') }

  it 'includes strong guidance for obvious quantity and ranking changes in saved query titles' do
    prompt = described_class.new(
      current_name: 'Top 5 longest-standing users',
      question: 'Show the 10 longest-standing users instead',
      sql: 'SELECT * FROM public.users ORDER BY created_at ASC LIMIT 10',
      data_source:,
      actor:
    )

    system_prompt = prompt.system_prompt

    expect(system_prompt).to include('Top 5 longest-standing users')
    expect(system_prompt).to include('10 longest-standing users')
    expect(system_prompt).to include('different LIMIT => aligned')
  end

  it 'includes the latest natural-language refinement request in the user prompt' do
    prompt = described_class.new(
      current_name: 'Top 5 longest-standing users',
      question: 'Show the 10 longest-standing users instead',
      sql: 'SELECT * FROM public.users ORDER BY created_at ASC LIMIT 10',
      data_source:,
      actor:
    )

    user_prompt = prompt.user_prompt

    expect(user_prompt).to include('Recent user request: Show the 10 longest-standing users instead')
    expect(user_prompt).to include('Current saved query name: Top 5 longest-standing users')
  end
end
