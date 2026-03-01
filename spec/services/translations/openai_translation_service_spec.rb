# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Translations::OpenaiTranslationService, type: :service do
  describe '#call' do
    let(:translation_key) { TranslationKey.create!(key: 'sample.key', area_tags: ['admin'], type_tags: ['copy']) }
    let(:service) do
      described_class.new(
        source_text: 'Hello',
        source_locale: 'en',
        target_locale: 'es',
        translation_key:
      )
    end
    let(:http_client) { instance_double(Net::HTTP) }

    before do
      allow(service).to receive(:http_client).and_return(http_client)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-key')
      allow(ENV).to receive(:fetch).with('OPENAI_TRANSLATIONS_MODEL', 'gpt-4.1-mini').and_return('gpt-4.1-mini')
    end

    it 'returns text when output_text is present' do
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(response).to receive(:body).and_return({ output_text: 'Hola' }.to_json)
      allow(http_client).to receive(:request).and_return(response)

      expect(service.call).to eq('Hola')
    end

    it 'returns text from nested output content when output_text is absent' do
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(response).to receive(:body).and_return(
        {
          output: [
            {
              type: 'message',
              content: [
                { type: 'output_text', text: 'Hola desde output' }
              ]
            }
          ]
        }.to_json
      )
      allow(http_client).to receive(:request).and_return(response)

      expect(service.call).to eq('Hola desde output')
    end

    it 'raises when response has no translated text' do
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(response).to receive(:body).and_return({ output: [] }.to_json)
      allow(http_client).to receive(:request).and_return(response)

      expect { service.call }.to raise_error(
        Translations::OpenaiTranslationService::RequestError,
        'OpenAI response was empty'
      )
    end
  end
end
