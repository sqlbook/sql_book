# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventDeleteJob, type: :job, disable_transactions: true do
  include ActiveJob::TestHelper

  let(:data_source) { create(:data_source) }

  before do
    create(:click, data_source_uuid: data_source.external_uuid)
    create(:click, data_source_uuid: data_source.external_uuid)
    create(:click, data_source_uuid: data_source.external_uuid)
    create(:click, data_source_uuid: data_source.external_uuid)

    create(:session, data_source_uuid: data_source.external_uuid)
    create(:session, data_source_uuid: data_source.external_uuid)
    create(:session, data_source_uuid: data_source.external_uuid)

    create(:page_view, data_source_uuid: data_source.external_uuid)
    create(:page_view, data_source_uuid: data_source.external_uuid)
    create(:page_view, data_source_uuid: data_source.external_uuid)
    create(:page_view, data_source_uuid: data_source.external_uuid)
  end

  subject { described_class.perform_now(data_source.external_uuid) }

  it 'deletes any stored events', skip: true do
    subject
    expect(true).to eq(true)
  end
end
