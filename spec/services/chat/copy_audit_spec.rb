# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::CopyAudit do
  subject(:audit) { described_class.new }

  it 'classifies every app.workspaces.chat locale key' do
    expect(audit.unclassified_keys).to be_empty
  end

  it 'keeps the chat locale tree inside the retained namespaces' do
    expect(audit.keys_outside_retained_namespaces).to be_empty
  end

  it 'has no deprecated chat locale namespace consumers in app code' do
    expect(audit.deprecated_namespace_consumers).to be_empty
  end
end
