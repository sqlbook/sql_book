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
end
