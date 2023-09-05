# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
{
  title: 'PDFMonkey',

  connection: {
    fields: [
      {
        name: 'api_key',
        label: 'Secret Key',
        control_type: 'password',
        optional: false,
        hint: 'You can find this key in the PDFMonkey dashboard, in the ' \
              '<a' \
              '  href="https://dashboard.pdfmonkey.io/account"' \
              '  target="_blank"' \
              '>My Account page</a>.'
      }
    ],

    authorization: {
      type: 'custom_auth',
      apply: lambda do |connection|
        headers(
          'Authorization' => "Bearer #{connection['api_key']}",
          'User-Agent' => 'Workato')
      end
    },

    base_uri: ->(_connection) { 'https://api.pdfmonkey.io/api/v1/' }
  },

  test: -> { get('current_user') },

  actions: {
    delete_document: {
      title: 'Delete Document',
      subtitle: 'Deletes a Document in PDFMonkey',

      description: lambda do
        "Deletes a <span class='provider'>Document</span>" \
          " in <span class='provider'>PDFMonkey</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [
          {
            name: 'document_id',
            label: 'Document ID',
            control_type: 'string',
            optional: false
          }
        ]
      end,

      execute: lambda do |_connection, input|
        delete("documents/#{input['document_id']}")
          .after_error_response(401, 404, 500) do |_code, body, _headers, _message|
            call(:handle_api_error, 'Deletion', body)
          end
      end,

      output_fields: ->(_object_definitions) { [] },

      sample_output: {}
    },

    generate_document: {
      title: 'Generate Document',
      subtitle: 'Creates a Document in PDFMonkey and wait for its generation',

      description: lambda do
        "Generates a <span class='provider'>Document</span> " \
          "in <span class='provider'>PDFMonkey</span>"
      end,

      input_fields: lambda do
        [
          {
            name: 'workspace_id',
            label: 'Workspace',
            control_type: 'select',
            optional: false,
            pick_list: 'workspaces'
          },
          {
            name: 'template_id',
            label: 'Template',
            control_type: 'select',
            optional: false,
            sticky: true,
            pick_list: 'templates',
            pick_list_params: { workspace_id: 'workspace_id' }
          },
          {
            name: 'real_json',
            label: 'Use a custom JSON structure',
            hint: 'Select Yes if you prefer writing a complete JSON payload instead of a basic' \
                  ' key/value mapping for the Document data.',
            control_type: 'checkbox',
            type: 'boolean',
            default: false,
            sticky: true
          },
          {
            ngIf: 'input.real_json == "false"',
            name: 'payload',
            label: 'Payload',
            control_type: 'key_value',
            optional: true,
            sticky: true,
            type: 'array',
            of: 'object',
            properties: [
              { name: 'key' },
              { name: 'value' }
            ],
            empty_list_title: 'Add data',
            empty_list_text: 'Add data to make it available in your Template'
          },
          {
            ngIf: 'input.real_json == "true"',
            name: 'payload_as_json',
            label: 'Payload',
            control_type: 'text-area',
            optional: true,
            sticky: true,
            type: 'string',
            hint: 'Write a complete JSON payload instead of a basic key/value mapping for the' \
                  ' Document data.'
          },
          {
            name: 'filename',
            label: 'Filename',
            control_type: 'text',
            optional: true,
            sticky: true
          },
          {
            name: 'meta',
            label: 'Meta Data',
            control_type: 'key_value',
            optional: true,
            sticky: true,
            type: 'array',
            of: 'object',
            properties: [
              { name: 'key' },
              { name: 'value' }
            ],
            empty_list_title: 'Add meta-data',
            empty_list_text: 'Add meta-data to your Document'
          },
          {
            name: 'wait_for_query',
            label: 'Wait for the generation to complete',
            control_type: 'checkbox',
            optional: false,
            default: 'true',
            advanced: true
          }
        ]
      end,

      execute: lambda do |_connection, input, _eis, _eos, continue|
        continue = {} unless continue.present?
        current_step = continue['current_step'] || 1

        # PDFMonkey will try 10x for 30s, which totals 300s (5min)
        # A 12-step incremental backoff amounts to 330s, which leaves enough room for 10 attempts.
        max_steps = 12
        step_time = current_step * 5

        if current_step == 1
          meta = call(:make_hash, input['meta'].presence)
          meta['_filename'] = meta['_filename'].presence || input['filename']

          payload =
            if input['real_json'] == 'true'
              parse_json(input['payload_as_json'] || '{}')
            else
              call(:make_hash, input['payload'])
            end

          params = {
            document: {
              document_template_id: input['template_id'],
              payload: payload,
              meta: meta || {},
              status: 'pending'
            }
          }

          response =
            post('documents', params)
            .after_response do |_code, body, _headers|
              call(:handle_document_response, 'Generation', body)
            end
            .after_error_response(400, 401, 422, 500) do |_code, body, _headers, _message|
              call(:handle_api_error, 'Generation', body)
            end

          status = response.dig('document', 'status')

          if %w[pending generating].include?(status) && input['wait_for_query'].is_true?
            reinvoke_after(
              seconds: step_time,
              continue: {
                current_step: current_step + 1,
                document_id: response.dig('document', 'id')
              })
          else
            response['document']
          end
        elsif current_step <= max_steps
          response =
            get("documents/#{continue['document_id']}")
            .after_response do |_code, body, _headers|
              call(:handle_document_response, 'Generation', body)
            end
            .after_error_response(401, 404, 500) do |_code, body, _headers, _message|
              call(:handle_api_error, 'Generation', body)
            end

          status = response.dig('document', 'status')

          if %w[pending generating].include?(status)
            reinvoke_after(
              seconds: step_time,
              continue: {
                current_step: current_step + 1,
                document_id: continue['document_id']
              })
          else
            response['document']
          end
        else
          error('Generation took too long!')
        end
      end,

      output_fields: ->(object_definitions) { object_definitions['document'] },

      sample_output: {
        app_id: '01c981ba-4540-4022-9cf9-0c7a18e6af0f',
        checksum: '8185b5b546b4318db8bfac2d5815c98a',
        created_at: '2020-01-01T18:41:20.396+01:00',
        document_template_id: '91fb5bcc-c81a-4b15-866b-4ce8c93d4201',
        download_url: 'https://pdfmonkey.s3-eu-west-1.amazonaws.com/production/documents/file/644bc7fa-30f5-4dc4-9d2a-fc7a2adcd927/demo-document.pdf?response-content-disposition=attachment&X-Amz-Expires=30&X-Amz-Date=20200305T150934Z&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJ2ZTKW4HLOMK63IQ%2F20200101%2Feu-west-1%2Fs3%2Faws4_request&X-Amz-SignedHeaders=host&X-Amz-Signature=0ae6dcc259ade24176c7f361c7efd27e4128b6fb6d675a09cd8e246bbe3ae5a3',
        filename: 'demo-document.pdf',
        id: '644bc7fa-30f5-4dc4-9d2a-fc7a2adcd927',
        meta: '{"_filename":"demo-document.pdf"}',
        payload: '{"name": "Jane Doe"}',
        preview_url: 'https://api.pdfmonkey.io/pdf-preview/minimal?file=https%3A%2F%2Fapi.pdfmonkey.io%2Fapi%2Fv1%2Fdocuments%2F644bc7fa-30f5-4dc4-9d2a-fc7a2adcd927%2Fpreview%3Fchecksum%3D8185b5b546b4318db8bfac2d5815c98a',
        share_link: 'https://files.pdfmonkey.io/sharing/11111111-2222-3333-4444-555555555555/demo-document.pdf',
        status: 'success',
        updated_at: '2020-01-01T18:41:20.396+01:00'
      }
    }
  },

  triggers: {
    document_generated: {
      title: 'Document generated',
      subtitle: 'Triggers when a Document is successfully generated.',

      description: lambda do
        "Successfully generated <span class='provider'>Document</span> " \
          "in <span class='provider'>PDFMonkey</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [
          {
            name: 'workspace_id',
            label: 'Workspace',
            control_type: 'select',
            optional: false,
            pick_list: 'workspaces'
          },
          {
            name: 'template_ids',
            label: 'Template(s)',
            control_type: 'multiselect',
            optional: true,
            sticky: true,
            pick_list: 'templates',
            pick_list_params: { workspace_id: 'workspace_id' },
            delimiter: ','
          },
          {
            name: 'since',
            label: 'When first started, this recipe should pick up events from',
            control_type: 'date_time',
            optional: true,
            sticky: true,
            hint: 'When you start recipe for the first time, it picks up trigger events from this' \
                  ' specified date and time. Defaults to the current time.'
          }
        ]
      end,

      poll: lambda do |_connection, input, closure, _eis, _eos|
        closure = closure.presence || {}
        updated_since = (closure['cursor'] || input['since'] || Time.now).to_time.utc

        params = {
          page: { size: 100 },
          q: {
            app_id: input['workspace_id'],
            document_template_id: input['template_ids'],
            status: 'success',
            updated_since: updated_since.to_i
          },
          sort: 'updated_at'
        }

        response =
          get('documents', params)
          .after_error_response(401, 404, 500) do |_code, body, _headers, _message|
            call(:handle_api_error, 'Document polling', body)
          end

        documents = response['documents']
        can_poll_more = response.dig('meta', 'next_page').present?

        closure['cursor'] = documents.any? ? documents.last['updated_at'] : updated_since.iso8601

        {
          events: documents,
          next_poll: closure,
          can_poll_more: can_poll_more
        }
      end,

      dedup: ->(document) { document['id'] },

      output_fields: ->(object_definitions) { object_definitions['document'] },

      sample_output: {
        app_id: '01c981ba-4540-4022-9cf9-0c7a18e6af0f',
        checksum: '8185b5b546b4318db8bfac2d5815c98a',
        created_at: '2020-01-01T18:41:20.396+01:00',
        document_template_id: '91fb5bcc-c81a-4b15-866b-4ce8c93d4201',
        download_url: 'https://pdfmonkey.s3-eu-west-1.amazonaws.com/production/documents/file/644bc7fa-30f5-4dc4-9d2a-fc7a2adcd927/demo-document.pdf?response-content-disposition=attachment&X-Amz-Expires=30&X-Amz-Date=20200305T150934Z&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJ2ZTKW4HLOMK63IQ%2F20200101%2Feu-west-1%2Fs3%2Faws4_request&X-Amz-SignedHeaders=host&X-Amz-Signature=0ae6dcc259ade24176c7f361c7efd27e4128b6fb6d675a09cd8e246bbe3ae5a3',
        filename: 'demo-document.pdf',
        id: '644bc7fa-30f5-4dc4-9d2a-fc7a2adcd927',
        meta: '{"_filename":"demo-document.pdf"}',
        payload: '{"name": "Jane Doe"}',
        preview_url: 'https://api.pdfmonkey.io/pdf-preview/minimal?file=https%3A%2F%2Fapi.pdfmonkey.io%2Fapi%2Fv1%2Fdocuments%2F644bc7fa-30f5-4dc4-9d2a-fc7a2adcd927%2Fpreview%3Fchecksum%3D8185b5b546b4318db8bfac2d5815c98a',
        share_link: 'https://files.pdfmonkey.io/sharing/11111111-2222-3333-4444-555555555555/demo-document.pdf',
        status: 'success',
        updated_at: '2020-01-01T18:41:20.396+01:00'
      }
    }
  },

  methods: {
    handle_api_error: lambda do |action_name, body|
      payload = parse_json(body)
      errors =
        if payload['error']
          [payload['error']]
        elsif payload['errors'].is_a?(Hash)
          payload['errors'].map { |key, value| "#{key}: #{value.to_a.join(', ')}" }
        else
          payload['errors'].to_a.map { |error| error['detail'] }
        end

      error(errors.join(', ').presence || "#{action_name} failed due to an unknown error")
    end,

    handle_document_response: lambda do |action_name, parsed_body|
      status = parsed_body.dig('document', 'status')

      if status == 'failure'
        failure_cause = parsed_body.dig('document', 'failure_cause').presence
        error(failure_cause || "#{action_name} failed due to an unknown cause")
      end

      parsed_body
    end,

    make_hash: lambda do |array_of_objects|
      if array_of_objects.blank?
        {}
      else
        Hash[array_of_objects.pluck('key', 'value')]
      end
    end,

    make_schema_builder_fields_sticky: lambda do |schema|
      schema.map do |field|
        if field['properties'].present?
          field['properties'] = call('make_schema_builder_fields_sticky', field['properties'])
        end

        field['sticky'] = true

        field
      end
    end
  },

  object_definitions: {
    document: {
      fields: lambda do
        [
          { name: 'id',                   label: 'ID',                          type: 'string'    },
          { name: 'app_id',               label: 'Workspace ID',                type: 'string'    },
          { name: 'created_at',           label: 'Created At',                  type: 'date_time' },
          { name: 'document_template_id', label: 'Template ID',                 type: 'string'    },
          { name: 'download_url',         label: 'Download URL (valid for 1h)', type: 'string'    },
          { name: 'filename',             label: 'Filename',                    type: 'string'    },
          { name: 'meta',                 label: 'Meta',                        type: 'string'    },
          { name: 'payload',              label: 'Payload',                     type: 'string'    },
          { name: 'share_link',           label: 'Share Link (premium only)',   type: 'string'    },
          { name: 'status',               label: 'Status',                      type: 'success'   },
          { name: 'updated_at',           label: 'Updated At',                  type: 'date_time' }
        ]
      end
    }
  },

  pick_lists: {
    workspaces: lambda do |_connection|
      response =
        get('app_cards')
        .after_error_response(401, 500) do |_code, body, _headers, _message|
          call(:handle_api_error, 'Listing workspaces', body)
        end

      response['app_cards'].pluck('identifier', 'id').sort_by { |(label, _id)| label }
    end,

    templates: lambda do |_connection, workspace_id:|
      response =
        get('document_template_cards', q: { app_id: workspace_id }, page: 'all')
        .after_error_response(401, 500) do |_code, body, _headers, _message|
          call(:handle_api_error, 'Listing workspaces', body)
        end

      response['document_template_cards']
        .map do |template|
          [
            [template['template_folder_identifier'], template['identifier']].compact.join('/'),
            template['id']
          ]
        end
        .sort_by { |(label, _id)| label }
        .sort_by { |pick_item| pick_item.first.include?('/') ? -1 : 1 }
    end
  }
}
# rubocop:enable Metrics/BlockLength
