# frozen_string_literal: true

require 'base64'
require 'json'
require 'net/http'

module Chat
  class RuntimeService # rubocop:disable Metrics/ClassLength
    ToolCall = Struct.new(:tool_name, :arguments, keyword_init: true)
    Decision = Struct.new(
      :assistant_message,
      :tool_calls,
      :missing_information,
      :finalize_without_tools,
      keyword_init: true
    )

    MAX_INLINE_IMAGE_COUNT = 2
    MAX_INLINE_IMAGE_SIZE = 5.megabytes
    EMAIL_REGEX = /[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i
    CHAT_MODEL_FALLBACK = 'gpt-4.1-mini'
    NAME_WITH_EMAIL_REGEX = /
      \b([a-z][a-z'\-\.]+)\s+([a-z][a-z'\-\.]+)
      (?:
        \s*[,;:]\s* |
        \s*[,;:]?\s+(?:whose\s+)?(?:e-?mail|correo)(?:\s+(?:address|electr[oó]nico))?\s*(?:is|es)?\s+ |
        \s+
      )
      #{EMAIL_REGEX.source}\b
    /ix
    INVITE_CONTEXT_REGEX = /\b(invitation|invite|invitar|invitacion|correo|email)\b/i
    INVITE_INTENT_REGEX = /\b(invite|invitar|invitaci[oó]n)\b/i
    MEMBER_REMOVE_INTENT_REGEX = /\b(remove|delete)\b.*\b(member|teammate|team mate|user)\b/i
    QUERY_SAVE_INTENT_REGEX = /\bsave\b/i
    QUERY_RENAME_INTENT_REGEX = /\b(rename|retitle|change)\b/i
    QUERY_UPDATE_INTENT_REGEX = /\b(update|replace|overwrite|edit|modify)\b/i
    QUERY_DELETE_INTENT_REGEX = /\b(delete|remove)\b.*\bquery\b/i
    QUERY_SAVE_AS_NEW_REGEX = /
      \b(
        save\s+(?:it|this|that)\s+as\s+(?:a\s+)?new\s+query|
        save\s+as\s+new|
        new\s+query|
        keep\s+both
      )\b
    /ix
    QUERY_UPDATE_EXISTING_REGEX = /
      \b(update|replace|overwrite)\b.*\b(existing|current|saved|old|that|this|one|query)\b
    /ix
    QUERY_RENAME_CONTEXT_REGEX = /
      \b(
        which\s+saved\s+query\s+to\s+rename|
        rename\s+it\b|
        what\s+would\s+you\s+like\s+to\s+rename|
        i\s+can\s+rename\s+it\s+to\b
      )\b
    /ix
    QUERY_DELETE_MISTAKE_REGEX = /\b(wrong|mistake|different|not\s+the\s+right)\b/i
    PLACEHOLDER_NAME_PARTS = %w[
      someone somebody anyone anybody person people team teammate teammates mate mates
      member members user users my our else another one this that
    ].freeze
    DECISION_SCHEMA = {
      'type' => 'object',
      'required' => %w[assistant_message tool_calls missing_information finalize_without_tools],
      'additionalProperties' => false,
      'properties' => {
        'assistant_message' => { 'type' => 'string' },
        'tool_calls' => {
          'type' => 'array',
          'items' => {
            'type' => 'object',
            'required' => %w[tool_name arguments],
            'additionalProperties' => false,
            'properties' => {
              'tool_name' => { 'type' => 'string' },
              'arguments' => { 'type' => 'string' }
            }
          }
        },
        'missing_information' => {
          'type' => 'array',
          'items' => { 'type' => 'string' }
        },
        'finalize_without_tools' => { 'type' => 'boolean' }
      }
    }.freeze

    def initialize(message:, workspace:, actor:, tool_metadata:, context: {})
      @message = message.to_s.strip
      @workspace = workspace
      @actor = actor
      @attachments = Array(context[:attachments]).compact
      @conversation_messages = Array(context[:conversation_messages]).compact
      @context_snapshot = context[:context_snapshot]
      @tool_metadata = Array(tool_metadata).compact
    end

    def call
      decision = llm_decision
      decision = apply_deterministic_guards(decision)
      return decision if decision

      fallback_decision
    rescue StandardError => e
      Rails.logger.warn("Chat runtime failed, falling back to planner: #{e.class} #{e.message}")
      fallback_decision
    end

    def compose_tool_result_message(tool_name:, tool_arguments:, execution:, fallback_message: nil)
      fallback_message ||= execution.user_message
      return fallback_message if api_key.blank?

      rendered = render_tool_result_with_models(
        tool_name:,
        tool_arguments:,
        execution:,
        fallback_message:
      )
      rendered.presence || fallback_message
    rescue StandardError => e
      Rails.logger.warn("Chat runtime result rendering failed: #{e.class} #{e.message}")
      fallback_message
    end

    private

    attr_reader :message, :workspace, :actor, :attachments, :conversation_messages, :context_snapshot, :tool_metadata

    def llm_decision
      return nil if api_key.blank?

      decision_from_models
    end

    def decision_from_models
      chat_model_candidates.each do |model|
        decision = decision_for_model(model:)
        return decision if decision
      end

      nil
    end

    def decision_for_model(model:)
      response = decision_response_for(model:)
      return nil unless response

      decision_from_response_body(response_body: response.body)
    rescue JSON::ParserError => e
      Rails.logger.warn("Chat runtime decision parse failed (model=#{model}): #{e.class} #{e.message}")
      nil
    end

    def render_tool_result_with_models(tool_name:, tool_arguments:, execution:, fallback_message:)
      chat_model_candidates.each do |model|
        rendered = rendered_tool_result_for_model(
          model:,
          tool_name:,
          tool_arguments:,
          execution:,
          fallback_message:
        )
        return rendered if rendered.present?
      end

      nil
    end

    def parse_decision_json(raw_json)
      parsed = parse_json_object(raw_json)
      return nil unless parsed.is_a?(Hash)

      Decision.new(
        assistant_message: parsed['assistant_message'].to_s,
        tool_calls: build_tool_calls(parsed:),
        missing_information: build_missing_information(parsed:),
        finalize_without_tools: parsed['finalize_without_tools'] == true
      )
    end

    def fallback_decision
      return planner_fallback_decision if api_key.blank?

      fallback_message_decision
    end

    def fallback_message_decision
      Decision.new(
        assistant_message: I18n.t('app.workspaces.chat.messages.runtime_retry'),
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      )
    end

    def planner_fallback_decision # rubocop:disable Metrics/AbcSize
      plan = Chat::PlannerService.new(
        message:,
        workspace:,
        actor:,
        attachments:,
        conversation_messages:,
        context_snapshot:
      ).call

      return fallback_message_decision if plan.nil?

      if plan.action_type.present?
        return Decision.new(
          assistant_message: plan.assistant_message.to_s,
          tool_calls: [ToolCall.new(tool_name: plan.action_type, arguments: plan.payload.to_h)],
          missing_information: [],
          finalize_without_tools: false
        )
      end

      Decision.new(
        assistant_message: plan.assistant_message.to_s,
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      )
    end

    def decision_response_for(model:)
      response = perform_request(payload: decision_request_payload(model:))
      return response if response.is_a?(Net::HTTPSuccess)

      log_response_failure(context: 'decision', model:, response:)
      nil
    end

    def decision_from_response_body(response_body:)
      parsed_response = JSON.parse(response_body)
      response_text = response_text_from(parsed_response)
      return nil if response_text.blank?

      parse_decision_json(response_text) || non_structured_decision(response_text:)
    end

    def non_structured_decision(response_text:)
      cleaned = normalized_markdown_text(response_text)
      return nil if cleaned.blank?
      return nil if cleaned.start_with?('{', '[')

      Decision.new(
        assistant_message: cleaned,
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      )
    end

    def rendered_tool_result_for_model(model:, tool_name:, tool_arguments:, execution:, fallback_message:)
      response = tool_result_response_for(
        model:,
        tool_name:,
        tool_arguments:,
        execution:,
        fallback_message:
      )
      return nil unless response

      parsed_tool_result_message(
        response_body: response.body,
        fallback_message:
      )
    rescue JSON::ParserError => e
      Rails.logger.warn("Chat runtime tool result parse failed (model=#{model}): #{e.class} #{e.message}")
      nil
    end

    def tool_result_response_for(model:, tool_name:, tool_arguments:, execution:, fallback_message:)
      response = perform_request(
        payload: tool_result_request_payload(
          model:,
          tool_name:,
          tool_arguments:,
          execution:,
          fallback_message:
        )
      )
      return response if response.is_a?(Net::HTTPSuccess)

      log_response_failure(context: 'tool_result', model:, response:)
      nil
    end

    def request(payload:)
      req = Net::HTTP::Post.new(endpoint)
      req['Authorization'] = "Bearer #{api_key}"
      req['Content-Type'] = 'application/json'
      req.body = payload.to_json
      req
    end

    def decision_request_payload(model:)
      {
        model:,
        input: [
          {
            role: 'system',
            content: [
              {
                type: 'input_text',
                text: system_prompt
              }
            ]
          },
          {
            role: 'user',
            content: user_input_content
          }
        ],
        text: decision_format
      }
    end

    def tool_result_request_payload(model:, tool_name:, tool_arguments:, execution:, fallback_message:)
      {
        model:,
        input: [
          {
            role: 'system',
            content: [
              {
                type: 'input_text',
                text: tool_result_system_prompt
              }
            ]
          },
          {
            role: 'user',
            content: [
              {
                type: 'input_text',
                text: [
                  "User locale: #{actor_locale}",
                  "Workspace: #{workspace.id} (#{workspace.name})",
                  "Original user message: #{message}",
                  "Tool called: #{tool_name}",
                  "Tool arguments: #{tool_arguments.to_json}",
                  "Execution status: #{execution.status}",
                  "Execution data: #{execution.data.to_json}",
                  "Default fallback message: #{fallback_message}"
                ].join("\n")
              }
            ]
          }
        ]
      }
    end

    def decision_format
      {
        format: {
          type: 'json_schema',
          name: 'chat_runtime_decision',
          schema: DECISION_SCHEMA,
          strict: true
        }
      }
    end

    def system_prompt # rubocop:disable Metrics/AbcSize
      [
        'You are sqlbook\'s workspace chat assistant operating inside one workspace.',
        'Keep the conversation natural and task-focused.',
        "Reply in the user locale: #{actor_locale}.",
        [
          'sqlbook can manage workspace settings, team members, connected data sources,',
          'saved queries, and read-only queries against those data sources.'
        ].join(' '),
        'Prioritize solving the user request over listing capabilities.',
        'Only provide capability summaries when the user explicitly asks what you can do.',
        'Use tool metadata schemas as your source of truth for required fields and argument shapes.',
        [
          'Use structured recent action context for continuity,',
          'but verify mutable current state through tools when needed.'
        ].join(' '),
        'Track the most recent invited, removed, or role-updated member across the thread.',
        'Extract required fields directly from natural-language user messages whenever possible.',
        [
          'If the user provides first name, last name, email, and role in one message,',
          'prepare member.invite immediately.'
        ].join(' '),
        'Treat explicit team/member language as workspace member management.',
        [
          'A plain request about "users" may refer either to workspace members or records in a data source.',
          'Use member.list only when the request is clearly about the team.'
        ].join(' '),
        'For "who are my team members" requests, call member.list.',
        [
          'Team member visibility is role-scoped.',
          'If the actor lacks permission to view the team list, explain that an Admin or Workspace owner can help.'
        ].join(' '),
        [
          'Owners and Admins can manage data sources in chat.',
          'Owners, Admins, and Users can view saved queries, run read-only data-source queries,',
          'save queries to the query library, rename saved queries, and update saved queries in chat.',
          'Deleting a saved query is destructive and requires confirmation.'
        ].join(' '),
        'If the user asks about saved queries or the query library, use query.list.',
        [
          'If the user wants to add a PostgreSQL data source, ask for the setup details in sensible chunks',
          'and continue from the saved setup state instead of asking for everything at once.'
        ].join(' '),
        [
          'If the user asks a data question, use query.run and rely on the live connected data sources and',
          'table/schema context. If multiple data sources or tables are plausible, ask a clarifying question.'
        ].join(' '),
        [
          'If the user says "save this query" after a successful query,',
          'reuse the recent query context.',
          [
            'If the latest draft is a refinement of an existing saved query,',
            'prefer query.update or ask whether to update the existing query or save a new one.'
          ].join(' ')
        ].join(' '),
        'If the user asks to rename a saved query, use query.rename.',
        'If the user asks to update a saved query to match the latest draft SQL, use query.update.',
        'If the user asks to delete a saved query, use query.delete.',
        'When user intent is specific, select a concrete tool call or ask one targeted follow-up.',
        'Use missing_information for required fields that are still absent.',
        'For member.invite, required fields are first_name, last_name, email, and role.',
        [
          'If invite context exists, collect all currently missing invite fields',
          'in one follow-up and continue until all required fields are present.'
        ].join(' '),
        [
          'Never choose or assume an invite role on the user\'s behalf.',
          'Ask for the role if it was not explicitly provided.'
        ].join(' '),
        [
          'Do not assume or invent a person\'s gender;',
          'use neutral phrasing like "them" unless the user provided pronouns.'
        ].join(' '),
        [
          'If the user says "invite them back" or similar, reuse the recent member identity',
          'if available, but still ask for role unless the user explicitly gave one.'
        ].join(' '),
        [
          'If the user asks what role a recently invited member was added as,',
          'answer from the recent structured invite result.'
        ].join(' '),
        'Treat natural role replies like "I think admin" or "make them admin" as explicit role instructions.',
        'Avoid repeating the same filler opening like "Sure." in consecutive replies.',
        'Do not fall back to a generic capability summary during invite follow-ups.',
        'When asked for team member names/details, use member.list and include detailed entries.',
        [
          'For member.resend_invite, member.update_role, and member.remove,',
          'you may target a member by email, member_id, or full_name.'
        ].join(' '),
        'For query.run, pass the user request as the question field.',
        'For query.save, include an explicit name only when the user provided one; otherwise let the app generate one.',
        'For query.rename, include query_id and the new name.',
        'For query.update, include query_id, sql, and name only when the user explicitly supplied a new name.',
        'For query.delete, include query_id and let the app render the confirmation step.',
        [
          'If the user names a workspace member directly, prefer a concrete tool call',
          'over a free-text confirmation question.'
        ].join(' '),
        [
          'When a write action requires confirmation, still return the tool call so',
          'the app can render inline confirm and cancel controls.'
        ].join(' '),
        'Never execute cross-workspace actions.',
        'Never invent permissions or claim execution outside provided tools.',
        'Do not say a tool is unavailable if it exists in the provided tool metadata.',
        'Do not wrap payload values with extra punctuation not intended by user input.',
        'Use markdown when it improves readability, especially bullet lists or tables for collections.',
        [
          'When it helps the conversation flow, end a successful in-scope reply with one light next step,',
          'for example a brief offer, a relevant follow-up question, or a concrete suggestion.'
        ].join(' '),
        [
          'Do this naturally and sparingly.',
          'Do not add a sign-off on every turn, and avoid generic filler like repeating "let me know" every time.'
        ].join(' '),
        [
          'Do not tack on a conversational sign-off for destructive confirmations, permission denials,',
          'validation failures, or when the user is clearly stopping.'
        ].join(' '),
        'Output strict JSON with keys: assistant_message, tool_calls, missing_information, finalize_without_tools.',
        'tool_calls must be an array of objects: { tool_name, arguments }.',
        'arguments must be a JSON string encoding an object, for example "{}" or "{\"email\":\"sam@example.com\"}".',
        'missing_information must be an array of short user-facing prompts.',
        'finalize_without_tools must be true only when no tool should run now.',
        "Available tools metadata:\n#{JSON.pretty_generate(tool_metadata)}"
      ].join(' ')
    end

    def tool_result_system_prompt
      [
        'You are sqlbook\'s workspace chat assistant.',
        'Write the final user-facing response from tool output.',
        'Be clear and concise; do not mention internal tool names.',
        'For ordinary tool results, sound natural and conversational rather than like a canned product string.',
        'If data is present, answer directly from that data.',
        'Use markdown when it improves readability.',
        'Preserve meaningful paragraph breaks.',
        'When presenting collections, use real markdown bullet lists or tables instead of inline dash-separated text.',
        [
          'When the result is successful and it helps, end with one short natural next step',
          'such as offering to save, rename, filter, or extend the result.'
        ].join(' '),
        [
          'Keep that forward-looking line brief and relevant.',
          'Do not add it to every answer, and do not use repetitive stock closers.'
        ].join(' '),
        'For member list results, put each member on its own bullet or row.',
        'If an action is forbidden, say who can perform it in natural language instead of repeating a flat refusal.',
        'If execution status is not executed, explain what failed and what the user can provide next.',
        'For member list results, include useful member details instead of only counts.',
        'When the fallback text sounds terse or product-like, improve the phrasing while preserving the exact meaning.',
        [
          'If you suggest renaming something, include the exact proposed name.',
          'Do not use vague placeholders like "something shorter or more descriptive".'
        ].join(' '),
        "Reply in the user locale: #{actor_locale}."
      ].join(' ')
    end

    def user_input_content
      content = [
        {
          type: 'input_text',
          text: [
            "User locale: #{actor_locale}",
            "Workspace: #{workspace.id} (#{workspace.name})",
            "Actor: #{actor.id}",
            conversation_context_line,
            attachment_context_line,
            "Message: #{message}"
          ].join("\n")
        }
      ]

      content.concat(inline_multimodal_images)
      content
    end

    def conversation_context_line # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      lines = transcript_messages.last(10).map do |entry|
        role = conversation_entry_role(entry)
        content = conversation_entry_content(entry)
        next if role.blank? || content.blank?

        "#{role}: #{content}"
      end.compact

      structured_lines = if context_snapshot.present?
                           Array(context_snapshot.structured_context_lines)
                         else
                           conversation_context_resolver.structured_context_lines
                         end
      return 'Recent conversation: none' if lines.empty? && structured_lines.empty?

      parts = []
      parts << "Recent conversation:\n#{lines.join("\n")}" if lines.any?
      parts << "Recent structured context:\n#{structured_lines.join("\n")}" if structured_lines.any?
      parts.join("\n")
    end

    def attachment_context_line
      return 'Image attachments count: 0' if attachments.empty?

      details = attachments.filter_map do |attachment|
        blob = attachment.blob
        next unless blob

        "#{blob.filename}(#{blob.content_type}, #{blob.byte_size} bytes)"
      end

      "Image attachments count: #{attachments.size} (#{details.join('; ')})"
    end

    def conversation_entry_role(entry)
      entry[:role].presence || entry['role'].presence
    end

    def conversation_entry_content(entry)
      raw = entry[:content].presence || entry['content'].presence || ''
      cleaned = raw.to_s.gsub(/\s+/, ' ').strip
      cleaned[0, 400]
    end

    def transcript_messages
      return context_snapshot.conversation_messages if context_snapshot.present?

      conversation_messages
    end

    def inline_multimodal_images
      attachments.filter_map do |attachment|
        blob = attachment.blob
        next unless blob
        next unless ChatMessage::ALLOWED_IMAGE_TYPES.include?(blob.content_type.to_s)
        next if blob.byte_size > MAX_INLINE_IMAGE_SIZE

        {
          type: 'input_image',
          image_url: "data:#{blob.content_type};base64,#{Base64.strict_encode64(attachment.download)}"
        }
      end.first(MAX_INLINE_IMAGE_COUNT)
    rescue StandardError => e
      Rails.logger.warn("Chat runtime skipped multimodal attachment encoding: #{e.class} #{e.message}")
      []
    end

    def perform_request(payload:)
      Net::HTTP.start(
        endpoint.host,
        endpoint.port,
        use_ssl: endpoint.scheme == 'https',
        read_timeout: 18,
        open_timeout: 4
      ) { |http| http.request(request(payload:)) }
    end

    def response_text_from(parsed)
      direct = parsed.fetch('output_text', '').to_s.strip
      return direct if direct.present?

      nested_output_text(parsed)
    end

    def nested_output_text(parsed)
      Array(parsed['output']).flat_map do |output_item|
        Array(output_item['content']).filter_map do |content_item|
          content_text(content_item)
        end
      end.join("\n").strip
    end

    def content_text(content_item)
      raw_text = content_item['text']
      value = raw_text.is_a?(Hash) ? raw_text['value'] : raw_text
      value.to_s.strip.presence
    end

    def parsed_tool_result_message(response_body:, fallback_message:)
      parsed = JSON.parse(response_body)
      formatted = normalized_markdown_text(response_text_from(parsed))
      formatted.presence || fallback_message
    rescue JSON::ParserError
      fallback_message
    end

    def build_tool_calls(parsed:)
      Array(parsed['tool_calls']).filter_map do |row|
        next unless row.is_a?(Hash)

        tool_name = row['tool_name'].to_s
        arguments = parsed_tool_arguments(row['arguments'])
        next if tool_name.blank?

        ToolCall.new(tool_name:, arguments:)
      end
    end

    def parsed_tool_arguments(raw_arguments)
      return raw_arguments if raw_arguments.is_a?(Hash)

      parse_json_object(raw_arguments.to_s).presence || {}
    end

    def build_missing_information(parsed:)
      Array(parsed['missing_information']).map(&:to_s).map(&:strip).compact_blank
    end

    def parse_json_object(raw_json)
      JSON.parse(raw_json)
    rescue JSON::ParserError
      parse_extracted_json(raw_json:)
    end

    def extract_json_object(raw_text)
      fenced = raw_text.match(/```(?:json)?\s*(\{.*\})\s*```/m)
      return fenced[1] if fenced

      first = raw_text.index('{')
      last = raw_text.rindex('}')
      return nil unless first && last && last > first

      raw_text[first..last]
    end

    def parse_extracted_json(raw_json:)
      extracted = extract_json_object(raw_json)
      return nil if extracted.blank?

      JSON.parse(extracted)
    rescue JSON::ParserError
      nil
    end

    def actor_locale
      actor.preferred_locale.presence || I18n.default_locale.to_s
    end

    def apply_deterministic_guards(decision)
      guarded = deterministic_follow_up_decision
      return decision unless should_apply_guard?(decision:, guarded:)

      guarded
    end

    def deterministic_follow_up_decision
      schema_summary_follow_up_decision ||
        query_follow_up_decision ||
        recent_invited_member_role_answer_decision ||
        recent_member_context_answer_decision ||
        member_remove_follow_up_decision ||
        invite_follow_up_guard_decision
    end

    def schema_summary_follow_up_decision
      response = Chat::SchemaSummaryFollowUpResponder.new(
        message:,
        conversation_messages: transcript_messages
      ).call
      return nil if response.blank?

      Decision.new(
        assistant_message: response,
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      )
    end

    def query_follow_up_decision
      query_run_follow_up_decision ||
        recent_query_delete_mistake_decision ||
        query_save_resolution_follow_up_decision ||
        query_update_follow_up_decision ||
        query_delete_follow_up_decision ||
        query_save_follow_up_decision ||
        query_rename_follow_up_decision
    end

    def query_run_follow_up_decision
      return nil unless contextual_query_run_follow_up?

      Decision.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_run'),
        tool_calls: [
          ToolCall.new(
            tool_name: 'query.run',
            arguments: { 'question' => message }
          )
        ],
        missing_information: [],
        finalize_without_tools: false
      )
    end

    def should_apply_guard?(decision:, guarded:)
      return false if guarded.nil?
      return true if decision.nil? || no_tool_selected?(decision)

      selected_tool_name = decision.tool_calls.first&.tool_name
      guarded_tool_name = guarded.tool_calls.first&.tool_name

      query_guard_override?(selected_tool_name:, guarded_tool_name:, guarded:)
    end

    def query_guard_override?(selected_tool_name:, guarded_tool_name:, guarded:)
      return true if query_save_guard_override?(selected_tool_name:, guarded_tool_name:)
      return true if query_mutation_guard_override?(selected_tool_name:, guarded_tool_name:)

      return false unless selected_tool_name == 'query.list'
      return true if %w[query.rename query.update query.delete].include?(guarded_tool_name)

      guarded.finalize_without_tools
    end

    def query_save_guard_override?(selected_tool_name:, guarded_tool_name:)
      guarded_tool_name == 'query.save' &&
        %w[query.list query.run].include?(selected_tool_name)
    end

    def query_mutation_guard_override?(selected_tool_name:, guarded_tool_name:)
      %w[query.rename query.update query.delete].include?(guarded_tool_name) &&
        %w[query.list query.run].include?(selected_tool_name)
    end

    def query_save_follow_up_decision # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      return nil unless query_save_follow_up?

      refinement = query_refinement_resolver.resolve
      if refinement.material_drift?
        return Decision.new(
          assistant_message: I18n.t(
            'app.workspaces.chat.planner.query_save_update_or_new',
            current_name: refinement.target_query.name,
            suggested_name: refinement.generated_name.presence || refinement.target_query.name
          ),
          tool_calls: [],
          missing_information: [],
          finalize_without_tools: true
        )
      end

      if refinement.minor_refinement?
        return build_query_update_decision(
          query_id: refinement.target_query.id,
          query_name: refinement.target_query.name,
          sql: refinement.draft_reference['sql'],
          name: QueryNameParser.parse(text: message)
        )
      end

      payload = {}
      explicit_name = QueryNameParser.parse(text: message)
      payload['name'] = explicit_name if explicit_name.present?

      Decision.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_save'),
        tool_calls: [
          ToolCall.new(
            tool_name: 'query.save',
            arguments: payload
          )
        ],
        missing_information: [],
        finalize_without_tools: false
      )
    end

    def query_save_resolution_follow_up_decision # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
      return nil unless query_save_resolution_context_active?

      refinement = query_refinement_resolver.resolve
      return nil unless refinement.target_query.present? && refinement.draft_reference['sql'].present?

      if message.match?(QUERY_SAVE_AS_NEW_REGEX)
        return build_query_save_decision(name: QueryNameParser.parse(text: message) || refinement.generated_name)
      end

      return nil unless message.match?(QUERY_UPDATE_EXISTING_REGEX)

      build_query_update_decision(
        query_id: refinement.target_query.id,
        query_name: refinement.target_query.name,
        sql: refinement.draft_reference['sql'],
        name: QueryNameParser.parse(text: message) || refinement.generated_name
      )
    end

    def recent_query_delete_mistake_decision
      deleted_query = recent_deleted_query
      return nil if deleted_query.blank?
      return nil unless message.match?(QUERY_DELETE_MISTAKE_REGEX)
      return nil unless message.match?(/\b(delete|deleted|query)\b/i)

      Decision.new(
        assistant_message: I18n.t(
          'app.workspaces.chat.planner.query_delete_mistake_follow_up',
          name: deleted_query['name']
        ),
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      )
    end

    def query_delete_follow_up_decision
      return nil unless query_delete_follow_up?

      query_reference = resolved_query_reference_payload
      return nil if query_reference['query_id'].blank?

      Decision.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_delete'),
        tool_calls: [
          ToolCall.new(
            tool_name: 'query.delete',
            arguments: query_reference
          )
        ],
        missing_information: [],
        finalize_without_tools: false
      )
    end

    def query_update_follow_up_decision
      return nil unless query_update_follow_up?

      query_reference = resolved_query_reference_payload
      draft_reference = recent_draft_query_reference_payload
      return nil if query_reference['query_id'].blank? || draft_reference['sql'].to_s.strip.blank?

      build_query_update_decision(
        query_id: query_reference['query_id'],
        query_name: query_reference['query_name'],
        sql: draft_reference['sql'],
        name: inferred_query_update_name
      )
    end

    def query_rename_follow_up_decision
      return nil unless query_rename_follow_up?

      query_name = inferred_query_rename_name
      query_reference = resolved_query_reference_payload
      return nil if query_name.blank? || query_reference['query_id'].blank?

      Decision.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_rename'),
        tool_calls: [
          ToolCall.new(
            tool_name: 'query.rename',
            arguments: query_reference.merge('name' => query_name)
          )
        ],
        missing_information: [],
        finalize_without_tools: false
      )
    end

    def invite_follow_up_guard_decision
      return nil unless invite_context_active?

      invite_details = inferred_invite_details
      missing_fields = missing_invite_fields(invite_details:)
      return invite_follow_up_decision(invite_details:) if missing_fields.empty?

      invite_missing_details_decision(missing_fields:)
    end

    def member_remove_follow_up_decision
      return nil unless message.match?(MEMBER_REMOVE_INTENT_REGEX)

      member_reference = resolved_member_reference_payload
      return nil if member_reference.empty?

      Decision.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.member_remove'),
        tool_calls: [ToolCall.new(tool_name: 'member.remove', arguments: member_reference)],
        missing_information: [],
        finalize_without_tools: false
      )
    end

    def no_tool_selected?(decision)
      decision.tool_calls.empty?
    end

    def query_rename_follow_up?
      explicit_query_rename_request? || rename_follow_up_context_active?
    end

    def query_update_follow_up?
      explicit_query_update_request?
    end

    def query_delete_follow_up?
      explicit_query_delete_request? || delete_follow_up_context_active?
    end

    def query_save_follow_up?
      return false unless message.match?(QUERY_SAVE_INTENT_REGEX)
      return false if explicit_query_rename_request? || explicit_query_update_request? || explicit_query_delete_request?

      recent_query_reference_payload.present? &&
        message.match?(/\b(save)\b.*\b(it|that|this|query|sql)\b/i)
    end

    def explicit_query_delete_request?
      message.match?(QUERY_DELETE_INTENT_REGEX)
    end

    def explicit_query_update_request?
      return false unless message.match?(QUERY_UPDATE_INTENT_REGEX)
      return false if recent_draft_query_reference_payload.blank?

      message.match?(/\b(query|sql|saved\s+query|existing|current|old|it|that|this)\b/i)
    end

    def delete_follow_up_context_active?
      return false unless message.match?(/\b(delete|remove)\b/i)

      message.match?(/\b(it|that|that one|same query|same one)\b/i) &&
        recent_assistant_content.to_s.match?(/\b(saved\s+queries?|query\s+library)\b/i)
    end

    def explicit_query_rename_request?
      return false unless message.match?(QUERY_RENAME_INTENT_REGEX)
      return false if message.match?(QUERY_UPDATE_INTENT_REGEX)

      message.match?(/\bquery\b/i) || inferred_query_rename_name.present?
    end

    def rename_follow_up_context_active?
      return false if inferred_query_rename_name.blank?

      recent_assistant_content.to_s.match?(QUERY_RENAME_CONTEXT_REGEX) || rename_target_selection_active?
    end

    def inferred_query_rename_name
      QueryNameParser.parse(text: message) ||
        recent_requested_query_name ||
        recent_proposed_query_rename_name
    end

    def inferred_query_update_name
      QueryNameParser.parse(text: message)
    end

    def recent_requested_query_name
      recent_user_conversation_texts.each do |text|
        parsed_name = QueryNameParser.parse(text:)
        return parsed_name if parsed_name.present?
      end

      nil
    end

    def recent_proposed_query_rename_name
      QueryNameParser.parse_proposed_rename_name(text: recent_assistant_original_content)
    end

    def resolved_query_reference_payload
      explicit_reference = query_reference_resolver.reference_payload(text: message)
      return explicit_reference if explicit_reference['query_id'].present?

      recent_saved_query_reference_payload
    end

    def rename_target_selection_active?
      recent_assistant_content.to_s.match?(/\b(saved\s+queries?|query\s+library)\b/i) &&
        query_reference_resolver.reference_payload(text: message)['query_id'].present?
    end

    def recent_saved_query_reference_payload
      recent_saved_query_reference = context_snapshot&.recent_saved_query_reference.to_h.deep_stringify_keys
      return {} if recent_saved_query_reference.blank?
      return {} if recent_saved_query_reference['saved_query_id'].to_s.strip.blank?

      {
        'query_id' => recent_saved_query_reference['saved_query_id'],
        'query_name' => recent_saved_query_reference['saved_query_name']
      }
    end

    def recent_query_reference_payload
      context_snapshot&.recent_query_reference.to_h.deep_stringify_keys
    end

    def contextual_query_run_follow_up?
      QueryFollowUpMatcher.contextual_follow_up?(
        text: message,
        recent_query_reference: recent_query_reference_payload
      )
    end

    def recent_draft_query_reference_payload
      context_snapshot&.recent_draft_query_reference.to_h.deep_stringify_keys
    end

    def query_reference_resolver
      @query_reference_resolver ||= QueryReferenceResolver.new(
        workspace:,
        query_references: context_snapshot&.query_references,
        recent_query_state: context_snapshot&.recent_query_state,
        conversation_messages:
      )
    end

    def query_refinement_resolver
      @query_refinement_resolver ||= QueryRefinementResolver.new(
        workspace:,
        context_snapshot:
      )
    end

    def query_save_resolution_context_active?
      recent_assistant_original_content.to_s.match?(/\bupdate\b.+\bsave\b.+\bnew query\b/i)
    end

    def build_query_save_decision(name: nil)
      payload = {}
      payload['name'] = name if name.present?

      Decision.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_save'),
        tool_calls: [ToolCall.new(tool_name: 'query.save', arguments: payload)],
        missing_information: [],
        finalize_without_tools: false
      )
    end

    def build_query_update_decision(query_id:, query_name:, sql:, name: nil)
      payload = {
        'query_id' => query_id,
        'query_name' => query_name,
        'sql' => sql
      }
      payload['name'] = name if name.present?

      Decision.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.query_update'),
        tool_calls: [ToolCall.new(tool_name: 'query.update', arguments: payload)],
        missing_information: [],
        finalize_without_tools: false
      )
    end

    def recent_deleted_query
      conversation_messages.reverse_each do |entry|
        next unless conversation_entry_role(entry) == 'assistant'

        deleted_query = result_data(entry)['deleted_query'] || result_data(entry)[:deleted_query]
        return deleted_query.to_h.deep_stringify_keys if deleted_query.present?
      end

      {}
    end

    def result_data(entry)
      metadata = entry[:metadata].presence || entry['metadata'].presence || {}
      metadata['result_data'] || metadata[:result_data] || {}
    end

    def invite_context_active?
      message.match?(INVITE_INTENT_REGEX) ||
        invite_follow_up_message?
    end

    def invite_context_in_recent_messages?
      invite_follow_up_context?
    end

    def invite_follow_up_message?
      return false unless invite_context_in_recent_messages?

      parsed_email.present? ||
        parsed_name_payload.present? ||
        parsed_role.present? ||
        message.match?(/\b(him|her|them)\b/i)
    end

    def inferred_invite_details
      details = conversation_context_resolver.invite_seed_details(text: message)
        .slice('email', 'first_name', 'last_name')
        .merge(invite_details_from_recent_user_messages)
      details['email'] = parsed_email if parsed_email.present?
      details.merge!(parsed_name_payload)
      details['role'] ||= parsed_role
      details
    end

    def invite_details_from_recent_user_messages
      details = {}
      recent_user_conversation_texts.each do |text|
        merge_recent_invite_details!(details:, text:)
        break if invite_details_complete?(details:)
      end

      details
    end

    def invite_follow_up_context?
      recent_assistant_text = recent_assistant_content
      return false if recent_assistant_text.blank?

      recent_assistant_text.match?(INVITE_CONTEXT_REGEX) ||
        invite_follow_up_prompts.include?(recent_assistant_text)
    end

    def recent_user_conversation_texts
      conversation_messages.reverse_each.filter_map do |entry|
        conversation_entry_content(entry) if conversation_entry_role(entry) == 'user'
      end
    end

    def merge_recent_invite_details!(details:, text:)
      invite_details_from_text(text:).each do |key, value|
        details[key] ||= value
      end
    end

    def invite_details_from_text(text:)
      parsed_name = parsed_name_payload_from(text:)

      {
        'email' => parse_email_from(text:),
        'first_name' => parsed_name['first_name'],
        'last_name' => parsed_name['last_name'],
        'role' => parsed_role_from(text:)
      }.compact_blank
    end

    def invite_details_complete?(details:)
      missing_invite_fields(invite_details: details).empty?
    end

    def invite_follow_up_prompts
      @invite_follow_up_prompts ||= %w[
        member_invite_needs_role
        member_invite_needs_name
        member_invite_needs_email
        member_invite_needs_email_and_role
        member_invite_needs_name_and_role
        member_invite_needs_email_and_name
        member_invite_needs_email_name_and_role
      ].map { |key| I18n.t("app.workspaces.chat.planner.#{key}").downcase }
    end

    def missing_invite_fields(invite_details:) # rubocop:disable Metrics/AbcSize
      fields = []
      fields << 'email' if invite_details['email'].to_s.strip.blank?
      fields << 'first_name' if invite_details['first_name'].to_s.strip.blank?
      fields << 'last_name' if invite_details['last_name'].to_s.strip.blank?
      fields << 'role' if invite_details['role'].to_s.strip.blank?
      fields
    end

    def invite_follow_up_decision(invite_details:)
      payload = {
        'email' => invite_details['email'],
        'first_name' => invite_details['first_name'],
        'last_name' => invite_details['last_name'],
        'role' => invite_details['role']
      }

      Decision.new(
        assistant_message: I18n.t('app.workspaces.chat.planner.member_invite'),
        tool_calls: [ToolCall.new(tool_name: 'member.invite', arguments: payload)],
        missing_information: [],
        finalize_without_tools: false
      )
    end

    def invite_missing_details_decision(missing_fields:)
      prompt = invite_missing_details_prompt(missing_fields:)
      Decision.new(
        assistant_message: prompt,
        tool_calls: [],
        missing_information: [prompt],
        finalize_without_tools: true
      )
    end

    def invite_missing_details_prompt(missing_fields:)
      prompt_key = Chat::InvitePromptResolver.key_for(missing_fields:)
      I18n.t(prompt_key)
    end

    def parsed_email
      parse_email_from(text: message)
    end

    def parsed_role
      parsed_role_from(text: message)
    end

    def parsed_name_payload
      parsed_name_payload_from(text: message)
    end

    def resolved_member_reference_payload
      resolved_reference = member_reference_resolver.reference_payload(text: message)
      return resolved_reference if resolved_reference.present?
      if (context_member = conversation_context_resolver.recent_member_reference(text: message))
        return context_member.slice('member_id', 'email', 'full_name').compact_blank
      end

      parsed_email.present? ? { 'email' => parsed_email } : {}
    end

    def parse_email_from(text:)
      text[EMAIL_REGEX].to_s.downcase.presence
    end

    def parsed_role_from(text:)
      Chat::RoleParser.parse(text:)
    end

    def parsed_name_payload_from(text:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      match = text.match(
        /\b(?:name\s+is|called|se\s+llama)\s+([a-z][a-z'\-\.]+)\s+([a-z][a-z'\-\.]+)/i
      )
      if match
        payload = normalized_name_payload(match)
        return payload if valid_name_payload?(payload)
      end

      return {} if text.match?(/\b(?:invite|invitar)\s+(?:him|her|them)\b/i)

      invite_name_match = text.match(
        /\b(?:invite|invitar)\s+([a-z][a-z'\-\.]+)\s+([a-z][a-z'\-\.]+)/i
      )
      if invite_name_match
        payload = normalized_name_payload(invite_name_match)
        return payload if valid_name_payload?(payload)
      end

      name_before_email_match = text.match(NAME_WITH_EMAIL_REGEX)
      if name_before_email_match
        payload = normalized_name_payload(name_before_email_match)
        return payload if valid_name_payload?(payload)
      end

      simple_name_match = text.strip.match(/\A([a-z][a-z'\-\.]+)\s+([a-z][a-z'\-\.]+)\z/i)
      return {} unless simple_name_match

      payload = normalized_name_payload(simple_name_match)
      return {} unless valid_name_payload?(payload)

      payload
    end

    def normalized_name_payload(match_data)
      {
        'first_name' => normalize_name_part(match_data[1]),
        'last_name' => normalize_name_part(match_data[2])
      }
    end

    def normalize_name_part(value)
      value.to_s.strip.split(/\s+/).map(&:capitalize).join(' ')
    end

    def valid_name_payload?(payload)
      first = payload['first_name'].to_s.downcase
      last = payload['last_name'].to_s.downcase
      return false if first.blank? || last.blank?
      return false if PLACEHOLDER_NAME_PARTS.include?(first)
      return false if PLACEHOLDER_NAME_PARTS.include?(last)

      true
    end

    def normalized_markdown_text(value)
      value.to_s.gsub("\r\n", "\n").gsub(/\n{3,}/, "\n\n").strip
    end

    def recent_invited_member_role_answer_decision
      return nil unless conversation_context_resolver.role_question_context_active?(text: message)

      invited_member = conversation_context_resolver.recent_invited_member_for_role_question(text: message)
      return nil unless invited_member

      Decision.new(
        assistant_message: I18n.t(
          'app.workspaces.chat.planner.member_invite_role_answer',
          name: invited_member['full_name'].presence || invited_member['email'],
          role: invited_member['role_name'],
          status: invited_member['status_name']
        ),
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      )
    end

    def recent_member_context_answer_decision
      member = current_member_from_recent_context
      return nil if member.blank?
      return nil unless member_context_request?

      Decision.new(
        assistant_message: I18n.t(
          'app.workspaces.chat.planner.member_recent_reference_answer',
          name: member['full_name'].presence || member['email'],
          email: member['email'],
          role: member['role_name'],
          status: member['status_name']
        ),
        tool_calls: [],
        missing_information: [],
        finalize_without_tools: true
      )
    end

    def member_context_request?
      conversation_context_resolver.member_state_request?(text: message) ||
        conversation_context_resolver.identity_question?(text: message)
    end

    def current_member_from_recent_context
      conversation_context_resolver.current_member_for_recent_reference(text: message) ||
        current_member_from_recent_result_payload
    end

    def current_member_from_recent_result_payload
      member_payload = latest_recent_member_payload
      return nil if member_payload.blank?

      member = current_member_record_from(payload: member_payload)
      return nil unless member

      serialize_current_member(member:)
    end

    def latest_recent_member_payload
      conversation_messages.reverse_each do |entry|
        payload = result_data(entry).with_indifferent_access.slice(:invited_member, :removed_member, :member).values
          .find { |value| value.is_a?(Hash) }
        return payload.deep_stringify_keys if payload.present?
      end

      {}
    end

    def current_member_record_from(payload:)
      by_id = current_member_record_by_id(payload:)
      return by_id if by_id

      current_member_record_by_email(payload:)
    end

    def serialize_current_member(member:)
      {
        'member_id' => member.id,
        'email' => member.user&.email.to_s,
        'full_name' => member.user&.full_name.to_s,
        'role_name' => member.role_name,
        'status_name' => member.status_name
      }
    end

    def current_member_record_by_id(payload:)
      return nil if payload['member_id'].blank?

      workspace.members.includes(:user).find_by(id: payload['member_id'])
    end

    def current_member_record_by_email(payload:)
      email = payload['email'].to_s.strip.downcase
      return nil if email.blank?

      workspace.members.includes(:user).joins(:user).find_by(users: { email: })
    end

    def chat_model_candidates
      configured_model = ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-5-mini').to_s.strip
      candidates = [configured_model.presence || 'gpt-5-mini']
      candidates << CHAT_MODEL_FALLBACK unless candidates.include?(CHAT_MODEL_FALLBACK)
      candidates
    end

    def log_response_failure(context:, model:, response:)
      body = response.body.to_s.gsub(/\s+/, ' ').strip
      preview = body[0, 220]
      Rails.logger.warn(
        "Chat runtime #{context} response failed (model=#{model}): " \
        "status=#{response.code} body=#{preview}"
      )
    end

    def api_key
      ENV.fetch('OPENAI_API_KEY', nil)
    end

    def endpoint
      @endpoint ||= OpenaiConfiguration.responses_endpoint
    end

    def member_reference_resolver
      @member_reference_resolver ||= Chat::MemberReferenceResolver.new(workspace:)
    end

    def conversation_context_resolver
      @conversation_context_resolver ||= Chat::ConversationContextResolver.new(
        workspace:,
        conversation_messages: transcript_messages
      )
    end

    def recent_assistant_content
      recent_assistant_text = conversation_messages.reverse.find do |entry|
        conversation_entry_role(entry) == 'assistant'
      end
      return if recent_assistant_text.blank?

      conversation_entry_content(recent_assistant_text).downcase
    end

    def recent_assistant_original_content
      recent_assistant_text = conversation_messages.reverse.find do |entry|
        conversation_entry_role(entry) == 'assistant'
      end
      return if recent_assistant_text.blank?

      conversation_entry_content(recent_assistant_text)
    end
  end
end
