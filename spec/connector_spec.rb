# frozen_string_literal: true

RSpec.describe 'connector' do
  let(:connector) { Workato::Connector::Sdk::Connector.from_file('connector.rb', settings) }
  let(:settings) { Workato::Connector::Sdk::Settings.from_default_file }

  before do
    stub_request(:get, 'https://api.pdfmonkey.io/api/v1/current_user')
      .with(headers: {
        'Authorization' => "Bearer #{settings[:api_key]}",
        'User-Agent' => 'Workato'
      })
      .to_return(
        status: 200,
        body: payload(:current_user),
        headers: { 'content-type': 'application/json' })
  end

  describe 'test' do
    subject(:output) { connector.test(settings) }

    it 'returns the payload for the current user' do
      expect(output['current_user']).to eq({
        'id' => '11111111-2222-3333-4444-555555555555',
        'auth_token' => 'XXX',
        'available_documents' => 300,
        'created_at' => '2000-01-02T03:04:05.123+01:00',
        'current_plan' => 'free',
        'current_plan_interval' => 'month',
        'desired_name' => 'Test User',
        'email' => 'test@example.com',
        'lang' => 'en',
        'paying_customer' => false,
        'trial_ends_on' => nil,
        'updated_at' => '2000-01-02T03:04:05.123+01:00',
        'block_resources' => true
      })
    end
  end
end
