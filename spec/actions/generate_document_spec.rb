# frozen_string_literal: true

RSpec.describe 'actions/generate_document', :vcr do
  let(:connector) { Workato::Connector::Sdk::Connector.from_file('connector.rb', settings) }
  let(:settings) { Workato::Connector::Sdk::Settings.from_default_file }

  let(:action) { connector.actions.generate_document }

  describe 'execute' do
    subject(:output) { action.execute(settings, input) }

    let(:input) {{
      workspace_id: '22222222-3333-4444-5555-666666666666',
      template_id: '44444444-5555-6666-7777-888888888888',
      payload: [
        { 'key' => 'key1', 'value' => 'value1' },
        { 'key' => 'key2', 'value' => 'value2' }
      ],
      filename: 'test-doc.pdf',
      meta: [
        { 'key' => 'key3', 'value' => 'value3' }
      ]
    }}

    context 'when the generation is successful' do
      before do
        stub_request(:post, endpoint('documents'))
          .with(
            body: {
              document: {
                document_template_id: '44444444-5555-6666-7777-888888888888',
                meta: { key3: 'value3', _filename: 'test-doc.pdf' },
                payload: { key1: 'value1', key2: 'value2' },
                status: 'pending'
              }
            },
            headers: {
              'content-type': 'application/json'
            })
          .to_return(
            status: 201,
            body: payload(:document_success),
            headers: { 'content-type': 'application/json' })
      end

      it 'returns the payload of the generated document' do
        expect(output).to eq({
          'id' => 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
          'created_at' => '2050-01-01T10:34:35.953+02:00',
          'document_template_id' => '44444444-5555-6666-7777-888888888888',
          'meta' => nil,
          'payload' => nil,
          'status' => 'success',
          'updated_at' => '2050-01-01T10:34:36.195+02:00',
          'app_id' => '22222222-3333-4444-5555-666666666666',
          'download_url' => 'https://pdfmonkey.s3.eu-west-1.amazonaws.com/test/backend/document/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/test-file.pdf?response-content-disposition=attachment&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=XXX%2F20500101%2Feu-west-1%2Fs3%2Faws4_request&X-Amz-Date=20500101T103435Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host&X-Amz-Signature=XXX',
          'checksum' => 'abcdef0123456789abcdef0123456789',
          'failure_cause' => nil,
          'filename' => 'test-file.pdf',
          'generation_logs' => [],
          'preview_url' => 'https://preview.pdfmonkey.io/pdf/web/viewer.html?file=https%3A%2F%2Fpreview.pdfmonkey.io%2Fdocument-render%2Faaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee%2Fabcdef01234567890abcdef012345678',
          'public_share_link' => nil
        })
      end
    end

    context 'when the generation needs waiting' do
      before do
        stub_request(:post, endpoint('documents'))
          .to_return(
            status: 201,
            body: payload(:document_with_wait),
            headers: { 'content-type': 'application/json' })

        stub_request(:get, endpoint('documents/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'))
          .to_return(
            {
              status: 200,
              body: payload(:document_with_wait),
              headers: { 'content-type': 'application/json' }
            },
            {
              status: 200,
              body: payload(:document_success),
              headers: { 'content-type': 'application/json' }
            })
      end

      context 'and the user wants to wait for the generation to complete' do
        before { input['wait_for_query'] = true }

        it 'returns the payload of the generated document' do
          expect(output).to eq({
            'id' => 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
            'created_at' => '2050-01-01T10:34:35.953+02:00',
            'document_template_id' => '44444444-5555-6666-7777-888888888888',
            'meta' => nil,
            'payload' => nil,
            'status' => 'success',
            'updated_at' => '2050-01-01T10:34:36.195+02:00',
            'app_id' => '22222222-3333-4444-5555-666666666666',
            'download_url' => 'https://pdfmonkey.s3.eu-west-1.amazonaws.com/test/backend/document/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/test-file.pdf?response-content-disposition=attachment&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=XXX%2F20500101%2Feu-west-1%2Fs3%2Faws4_request&X-Amz-Date=20500101T103435Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host&X-Amz-Signature=XXX',
            'checksum' => 'abcdef0123456789abcdef0123456789',
            'failure_cause' => nil,
            'filename' => 'test-file.pdf',
            'generation_logs' => [],
            'preview_url' => 'https://preview.pdfmonkey.io/pdf/web/viewer.html?file=https%3A%2F%2Fpreview.pdfmonkey.io%2Fdocument-render%2Faaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee%2Fabcdef01234567890abcdef012345678',
            'public_share_link' => nil
          })
        end
      end

      context 'and the user does not want to wait for the generation to complete' do
        before { input['wait_for_query'] = false }

        it 'returns the payload of the generated document' do
          expect(output).to eq({
            'id' => 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
            'created_at' => '2050-01-01T10:34:35.953+02:00',
            'document_template_id' => '44444444-5555-6666-7777-888888888888',
            'meta' => nil,
            'payload' => nil,
            'status' => 'generating',
            'updated_at' => '2050-01-01T10:34:36.195+02:00',
            'app_id' => '22222222-3333-4444-5555-666666666666',
            'download_url' => nil,
            'checksum' => 'abcdef0123456789abcdef0123456789',
            'failure_cause' => nil,
            'filename' => 'test-file.pdf',
            'generation_logs' => [],
            'preview_url' => 'https://preview.pdfmonkey.io/pdf/web/viewer.html?file=https%3A%2F%2Fpreview.pdfmonkey.io%2Fdocument-render%2Faaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee%2Fabcdef01234567890abcdef012345678',
            'public_share_link' => nil
          })
        end
      end
    end

    context 'when the generation fails with a failure cause' do
      before do
        stub_request(:post, endpoint('documents'))
          .to_return(
            status: 201,
            body: payload(:document_failure),
            headers: { 'content-type': 'application/json' })
      end

      it 'raises an exception with the failure cause' do
        expect { output }.to raise_exception('Quota exceeded')
      end
    end

    context 'when the generation fails with no failure cause' do
      before do
        stub_request(:post, endpoint('documents'))
          .to_return(
            status: 400,
            body: payload(:document_error),
            headers: { 'content-type': 'application/json' })
      end

      it 'raises an exception with the error message' do
        expect { output }.to raise_exception(
          'unexpected character (after document.document_template_id) at line 1, column 48')
      end
    end

    context 'when the generation needs waiting and it fails with a failure cause' do
      before do
        input['wait_for_query'] = true

        stub_request(:post, endpoint('documents'))
          .to_return(
            status: 201,
            body: payload(:document_with_wait),
            headers: { 'content-type': 'application/json' })

        stub_request(:get, endpoint('documents/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'))
          .to_return(
            {
              status: 200,
              body: payload(:document_with_wait),
              headers: { 'content-type': 'application/json' }
            },
            {
              status: 200,
              body: payload(:document_failure),
              headers: { 'content-type': 'application/json' }
            })
      end

      it 'raises an exception with the failure cause' do
        expect { output }.to raise_exception('Quota exceeded')
      end
    end

    context 'when the generation needs waiting and it fails with no failure cause' do
      before do
        input['wait_for_query'] = true

        stub_request(:post, endpoint('documents'))
          .to_return(
            status: 201,
            body: payload(:document_with_wait),
            headers: { 'content-type': 'application/json' })

        stub_request(:get, endpoint('documents/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'))
          .to_return(
            {
              status: 200,
              body: payload(:document_with_wait),
              headers: { 'content-type': 'application/json' }
            },
            {
              status: 500,
              body: payload(:document_error),
              headers: { 'content-type': 'application/json' }
            })
      end

      it 'raises an exception with the failure cause' do
        expect { output }.to raise_exception(
          'unexpected character (after document.document_template_id) at line 1, column 48')
      end
    end
  end

  describe 'output_fields' do
    subject(:output_fields) { action.output_fields(settings, { type: :event }) }

    it 'returns the :document object definition' do
      expect(output_fields).to eq(connector.object_definitions.document.fields)
    end
  end
end
