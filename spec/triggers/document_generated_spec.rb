# frozen_string_literal: true

RSpec.describe 'triggers/document_generated', :freeze_time do
  let(:connector) { Workato::Connector::Sdk::Connector.from_file('connector.rb', settings) }
  let(:settings) { Workato::Connector::Sdk::Settings.from_default_file }

  let(:trigger) { connector.triggers.document_generated }

  def stub_document_request(updated_since:, payload:, status: 200)
    stub_request(:get, endpoint('documents'))
      .with({
        query: {
          page: { size: 100 },
          q: {
            app_id: '22222222-3333-4444-5555-666666666666',
            document_template_id: '66666666-7777-8888-9999-000000000000',
            status: 'success',
            updated_since: updated_since
          },
          sort: 'updated_at'
        }
      })
      .to_return(
        status: status,
        body: payload(payload),
        headers: { 'content-type': 'application/json' })
  end

  describe 'poll' do
    context 'when no :since input nor :closure is specified' do
      subject(:output) { trigger.poll(settings, input) }

      let(:input) {{
        workspace_id: '22222222-3333-4444-5555-666666666666',
        template_ids: '66666666-7777-8888-9999-000000000000'
      }}

      before do
        stub_document_request(
          updated_since: 2_524_705_445, # 2050-01-02T03:04:05Z
          payload: :documents_no_since_no_closure)
      end

      it 'returns an empty list of events' do
        expect(output).to eq({
          'events' => [],
          'next_poll' => { 'cursor' => '2050-01-02T03:04:05Z' },
          'can_poll_more' => false
        })
      end
    end

    context 'when no :since input is specified but a :closure is provided' do
      subject(:output) { trigger.poll(settings, input, { 'cursor' => '2049-12-31T12:34:56Z' }) }

      let(:input) {{
        workspace_id: '22222222-3333-4444-5555-666666666666',
        template_ids: '66666666-7777-8888-9999-000000000000'
      }}

      before do
        stub_document_request(
          updated_since: 2_524_566_896, # 2049-12-31T12:34:56Z
          payload: :documents_with_since_or_closure)
      end

      it 'returns a list of events' do
        expected_events =
          JSON
          .parse(payload(:documents_with_since_or_closure))['documents']

        expect(output).to match({
          'events' => expected_events.reverse,
          'next_poll' => { 'cursor' => '2050-01-01T10:35:36.195+02:00' },
          'can_poll_more' => false
        })
      end
    end

    context 'when a :since input is specified and a closure is provided' do
      subject(:output) { trigger.poll(settings, input, { 'cursor' => '2049-12-31T12:34:56Z' }) }

      let(:input) {{
        workspace_id: '22222222-3333-4444-5555-666666666666',
        template_ids: '66666666-7777-8888-9999-000000000000',
        since: '2049-11-31T12:34:56Z'
      }}

      before do
        stub_document_request(
          updated_since: 2_524_566_896, # 2049-12-31T12:34:56Z
          payload: :documents_with_since_or_closure)
      end

      it 'returns a list of events' do
        expected_events =
          JSON
          .parse(payload(:documents_with_since_or_closure))['documents']

        expect(output).to match({
          'events' => expected_events.reverse,
          'next_poll' => { 'cursor' => '2050-01-01T10:35:36.195+02:00' },
          'can_poll_more' => false
        })
      end
    end

    context 'when a :since input is specified and no closure is provided' do
      subject(:output) { trigger.poll(settings, input) }

      let(:input) {{
        workspace_id: '22222222-3333-4444-5555-666666666666',
        template_ids: '66666666-7777-8888-9999-000000000000',
        since: '2049-11-31T12:34:56Z'
      }}

      before do
        stub_document_request(
          updated_since: 2_521_974_896, # 2049-11-31T12:34:56Z
          payload: :documents_with_since_or_closure)
      end

      it 'returns a list of events' do
        expected_events =
          JSON
          .parse(payload(:documents_with_since_or_closure))['documents']

        expect(output).to match({
          'events' => expected_events.reverse,
          'next_poll' => { 'cursor' => '2050-01-01T10:35:36.195+02:00' },
          'can_poll_more' => false
        })
      end
    end

    context 'when there are more documents to poll' do
      subject(:output) { trigger.poll(settings, input) }

      let(:input) {{
        workspace_id: '22222222-3333-4444-5555-666666666666',
        template_ids: '66666666-7777-8888-9999-000000000000',
        since: '2049-11-31T12:34:56Z'
      }}

      before do
        stub_document_request(
          updated_since: 2_521_974_896, # 2049-11-31T12:34:56Z
          payload: :documents_with_second_page_page1)

        stub_document_request(
          updated_since: 2_524_638_876, # 2050-01-01T10:34:36.195+02:00
          payload: :documents_with_second_page_page2)
      end

      it 'returns a list of events' do
        expected_events = [
          JSON.parse(payload(:documents_with_second_page_page1))['documents'].first,
          JSON.parse(payload(:documents_with_second_page_page2))['documents'].first
        ]

        expect(output).to eq({
          'events' => expected_events.reverse,
          'next_poll' => { 'cursor' => '2050-01-01T10:35:36.195+02:00' },
          'can_poll_more' => false
        })
      end
    end

    context 'when the API call fails' do
      subject(:output) { trigger.poll(settings, input) }

      let(:input) {{
        workspace_id: '22222222-3333-4444-5555-666666666666',
        template_ids: '66666666-7777-8888-9999-000000000000'
      }}

      before do
        stub_document_request(
          updated_since: 2_524_705_445, # 2050-01-02T03:04:05Z
          payload: :documents_error,
          status: 401)
      end

      it 'raises an exception' do
        expect { output }.to raise_exception(
          'We were unable to authenticate you based on the provided API key. Please verify' \
          ' that you provided the intended key. We received a key statrting with xxx… If you' \
          ' think this is an error on our side feel free to contact us at support@pdfmonkey.io.')
      end
    end
  end

  describe 'dedup' do
    subject(:output) { trigger.dedup(record) }

    let(:record) {{ 'id' => 'xxx' }}

    it 'returns the record ID' do
      expect(output).to eq('xxx')
    end
  end

  describe 'output_fields' do
    subject(:output_fields) { trigger.output_fields(settings, { type: :event }) }

    it 'returns the :document object definition' do
      expect(output_fields).to eq(connector.object_definitions.document.fields)
    end
  end
end
