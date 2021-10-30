# frozen_string_literal: true

RSpec.describe 'pick_lists/templates' do
  let(:connector) { Workato::Connector::Sdk::Connector.from_file('connector.rb', settings) }
  let(:settings) { Workato::Connector::Sdk::Settings.from_default_file }

  context 'when the workspace contains templates' do
    subject(:pick_list) do
      connector.pick_lists.templates(settings, workspace_id: '22222222-3333-4444-5555-666666666666')
    end

    before do
      stub_request(:get, endpoint('document_template_cards'))
        .with(query: { page: 'all', 'q[app_id]': '22222222-3333-4444-5555-666666666666' })
        .to_return(
          status: 200,
          body: payload(:templates_test_user),
          headers: { 'content-type': 'application/json' })
    end

    it 'returns the list of templates for the given app' do
      expect(pick_list).to match([
        ['Other Folder/Test Template', '66666666-7777-8888-9999-000000000000'],
        ['Some Folder/Test Template',  '55555555-6666-7777-8888-999999999999'],
        ['A Test Template',            '44444444-5555-6666-7777-888888888888'],
        ['Another Test Template',      '77777777-8888-9999-0000-111111111111']
      ])
    end
  end

  context 'when the workspace has no template' do
    subject(:pick_list) do
      connector.pick_lists.templates(settings, workspace_id: '33333333-4444-5555-6666-777777777777')
    end

    before do
      stub_request(:get, endpoint('document_template_cards'))
        .with(query: { page: 'all', 'q[app_id]': '33333333-4444-5555-6666-777777777777' })
        .to_return(
          status: 200,
          body: payload(:templates_other_workspace),
          headers: { 'content-type': 'application/json' })
    end

    it 'retuens en empty list' do
      expect(pick_list).to eq([])
    end
  end
end
