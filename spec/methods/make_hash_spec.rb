# frozen_string_literal: true

RSpec.describe 'methods/make_hash' do
  let(:connector) { Workato::Connector::Sdk::Connector.from_file('connector.rb') }

  let(:output) { connector.methods.make_hash(input) }

  context 'when the input is blank' do
    let(:input) { nil }

    it 'returns an empty Hash' do
      expect(output).to eq({})
    end
  end

  context 'when the input is an empty array' do
    let(:input) { [] }

    it 'returns an empty Hash' do
      expect(output).to eq({})
    end
  end

  context 'when the input is an array of objects' do
    let(:input) do
      [
        { 'key' => 'firstname', 'value' => 'Jane' },
        { 'key' => 'lastname', 'value' => 'Doe' }
      ]
    end

    it 'returns a proper Hash' do
      expect(output).to eq({ 'firstname' => 'Jane', 'lastname' => 'Doe' })
    end
  end
end
