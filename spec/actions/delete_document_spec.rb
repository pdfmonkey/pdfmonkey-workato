# frozen_string_literal: true

RSpec.describe 'actions/delete_document', :vcr do
  let(:connector) { Workato::Connector::Sdk::Connector.from_file('connector.rb', settings) }
  let(:settings) { Workato::Connector::Sdk::Settings.from_default_file }

  let(:action) { connector.actions.delete_document }

  describe 'execute' do
    subject(:output) { action.execute(settings, input) }

    let(:input) {{ document_id: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' }}

    context 'when the document deletion is successful' do
      before do
        stub_request(:delete, endpoint('documents/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'))
          .to_return(status: 204, body: '')
      end

      it 'returns an empty payload' do
        expect(output).to eq({})
      end
    end

    context 'when the deletion fails' do
      before do
        stub_request(:delete, endpoint('documents/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'))
          .to_return(
            status: 404,
            body: payload(:deletion_error),
            headers: { 'content-type': 'json' })
      end

      it 'raises an exception' do
        error_message = 'We couldn’t find any Document with ID' \
                        ' "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee". If you are its App’s owner' \
                        ' please verify that you are sending the right API key in your request.' \
                        ' If you think it’s an error on our part, feel free to contact us at' \
                        ' support@pdfmonkey.io.'
        expect { output }.to raise_exception(error_message)
      end
    end
  end

  describe 'output_fields' do
    subject(:output_fields) { action.output_fields(settings, { type: :event }) }

    it 'returns the :document object definition' do
      expect(output_fields).to eq []
    end
  end
end
