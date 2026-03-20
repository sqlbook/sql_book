# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ViewHelper', type: :helper do
  describe '#class_names' do
    let(:scenarios) do
      [
        {
          class_names: %w[first second],
          conditionals: { third: true, forth: false },
          expected: 'first second third'
        },
        {
          class_names: %w[first second],
          conditionals: {},
          expected: 'first second'
        },
        {
          class_names: [],
          conditionals: { first: true, second: false, third: false },
          expected: 'first'
        }
      ]
    end

    it 'returns the expected string' do
      scenarios.each do |scenario|
        expect(helper.class_names(*scenario[:class_names], **scenario[:conditionals])).to eq(scenario[:expected])
      end
    end
  end

  describe '#add_params' do
    context 'when there are no existing params' do
      it 'adds the new ones' do
        expect(helper.add_params(foo: 'bar', bar: 'baz')).to eq(foo: 'bar', bar: 'baz')
      end
    end

    context 'when there are existing params' do
      before do
        allow(helper).to receive(:request).and_return(double(params: { aaa: 'aaa', bbb: 'bbb' }))
      end

      it 'adds the new ones' do
        expect(helper.add_params(foo: 'bar', bar: 'baz')).to eq(aaa: 'aaa', bbb: 'bbb', foo: 'bar', bar: 'baz')
      end
    end
  end

  describe '#normalize_step_indicator' do
    it 'returns normalized step values' do
      expect(helper.normalize_step_indicator(total_steps: '4', current_step: '2')).to eq([4, 2])
    end

    it 'raises when total_steps is not positive' do
      expect do
        helper.normalize_step_indicator(total_steps: 0, current_step: 1)
      end.to raise_error(ArgumentError, 'total_steps must be positive')
    end

    it 'raises when current_step is out of range' do
      expect do
        helper.normalize_step_indicator(total_steps: 3, current_step: 4)
      end.to raise_error(ArgumentError, 'current_step must be between 1 and total_steps')
    end
  end

  describe '#step_indicator_step_state' do
    it 'returns the correct state for each step' do
      expect(helper.step_indicator_step_state(step_number: 1, current_step: 2)).to eq('complete')
      expect(helper.step_indicator_step_state(step_number: 2, current_step: 2)).to eq('current')
      expect(helper.step_indicator_step_state(step_number: 3, current_step: 2)).to eq('upcoming')
    end
  end

  describe '#step_indicator_connector_state' do
    it 'returns complete for connectors before the current step' do
      expect(helper.step_indicator_connector_state(step_number: 1, current_step: 2)).to eq('complete')
    end

    it 'returns upcoming for connectors at or after the current step' do
      expect(helper.step_indicator_connector_state(step_number: 2, current_step: 2)).to eq('upcoming')
    end
  end

  describe '#step_indicator_status_label' do
    it 'builds a localized label for the step state' do
      expect(helper.step_indicator_status_label(step_number: 2, total_steps: 3, current_step: 2))
        .to eq('Step 2 of 3, current')
    end
  end

  describe 'shared/_step_indicator' do
    it 'renders the expected step and connector states' do
      render partial: 'shared/step_indicator', locals: { total_steps: 3, current_step: 2 }

      expect(rendered).to include('step-indicator__dot step-indicator__dot--complete')
      expect(rendered).to include('step-indicator__dot step-indicator__dot--current')
      expect(rendered).to include('step-indicator__dot step-indicator__dot--upcoming')
      expect(rendered).to include('step-indicator__connector step-indicator__connector--complete')
      expect(rendered).to include('step-indicator__connector step-indicator__connector--upcoming')
      expect(rendered).to include('Step 2 of 3, current')
    end
  end
end
