# frozen_string_literal: true

RSpec.describe 'pick_lists/workspaces' do
  subject(:pick_list) { connector.pick_lists.workspaces(settings) }

  let(:connector) { Workato::Connector::Sdk::Connector.from_file('connector.rb', settings) }
  let(:settings) { Workato::Connector::Sdk::Settings.from_default_file }

  before do
    stub_request(:get, endpoint('app_cards'))
      .to_return(
        status: 200,
        body: payload(:workspaces),
        headers: { 'content-type': 'application/json' })
  end

  it 'returns the list of workspaces' do
    expect(pick_list).to match([
      ['Other Workspace', '33333333-4444-5555-6666-777777777777'],
      ['Test User', '22222222-3333-4444-5555-666666666666']
    ])
  end
end
