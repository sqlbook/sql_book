# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tooling::Registry do
  let(:handler) do
    lambda do |arguments:|
      Tooling::Result.new(status: 'executed', message: 'ok', data: arguments, error_code: nil)
    end
  end
  let(:definitions) do
    [
      Tooling::Registry::ToolDefinition.new(
        name: 'member.invite',
        description: 'Invite member',
        input_schema: {
          'type' => 'object',
          'required' => ['email'],
          'properties' => {
            'email' => { 'type' => 'string', 'format' => 'email' }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'low',
        confirmation_mode: 'none',
        handler:
      )
    ]
  end

  describe '#execute' do
    it 'executes when arguments satisfy schema' do
      registry = described_class.new(definitions:)

      result = registry.execute(name: 'member.invite', arguments: { 'email' => 'new@example.com' })

      expect(result.status).to eq('executed')
      expect(result.data).to include('email' => 'new@example.com')
    end

    it 'raises validation errors for invalid payloads' do
      registry = described_class.new(definitions:)

      expect do
        registry.execute(name: 'member.invite', arguments: { 'email' => 'nope' })
      end.to raise_error(Tooling::ValidationError)
    end

    it 'raises unknown tool errors for missing definitions' do
      registry = described_class.new(definitions:)

      expect do
        registry.execute(name: 'workspace.unknown', arguments: {})
      end.to raise_error(Tooling::UnknownToolError)
    end
  end
end
