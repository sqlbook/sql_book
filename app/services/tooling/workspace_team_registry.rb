# frozen_string_literal: true

module Tooling
  module WorkspaceTeamRegistry
    module_function

    TOOL_CATALOG = [
      {
        name: 'workspace.update_name',
        description: 'Update the current workspace name.',
        input_schema: {
          'type' => 'object',
          'required' => ['name'],
          'properties' => {
            'name' => { 'type' => 'string', 'min_length' => 1 }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'low',
        confirmation_mode: 'none',
        handler_method: :workspace_update_name
      },
      {
        name: 'workspace.delete',
        description: 'Delete the current workspace.',
        input_schema: { 'type' => 'object', 'properties' => {} },
        output_schema: { 'type' => 'object' },
        risk_level: 'high',
        confirmation_mode: 'required',
        handler_method: :workspace_delete
      },
      {
        name: 'member.list',
        description: 'List members in the current workspace with details.',
        input_schema: { 'type' => 'object', 'properties' => {} },
        output_schema: { 'type' => 'object' },
        risk_level: 'read',
        confirmation_mode: 'none',
        handler_method: :member_list
      },
      {
        name: 'member.invite',
        description: 'Invite a member to the current workspace.',
        input_schema: {
          'type' => 'object',
          'required' => ['email'],
          'properties' => {
            'email' => { 'type' => 'string', 'format' => 'email' },
            'first_name' => { 'type' => 'string' },
            'last_name' => { 'type' => 'string' },
            'role' => { 'type' => 'integer', 'enum' => Chat::Policy::EDITABLE_ROLES }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'low',
        confirmation_mode: 'none',
        handler_method: :member_invite
      },
      {
        name: 'member.resend_invite',
        description: 'Resend a pending invitation to a member in the current workspace.',
        input_schema: {
          'type' => 'object',
          'properties' => {
            'member_id' => { 'type' => 'integer' },
            'email' => { 'type' => 'string', 'format' => 'email' }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'low',
        confirmation_mode: 'none',
        handler_method: :member_resend_invite
      },
      {
        name: 'member.update_role',
        description: 'Update a workspace member role.',
        input_schema: {
          'type' => 'object',
          'required' => ['role'],
          'properties' => {
            'member_id' => { 'type' => 'integer' },
            'email' => { 'type' => 'string', 'format' => 'email' },
            'role' => { 'type' => 'integer', 'enum' => Chat::Policy::EDITABLE_ROLES }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'high',
        confirmation_mode: 'required',
        handler_method: :member_update_role
      },
      {
        name: 'member.remove',
        description: 'Remove a workspace member.',
        input_schema: {
          'type' => 'object',
          'properties' => {
            'member_id' => { 'type' => 'integer' },
            'email' => { 'type' => 'string', 'format' => 'email' }
          }
        },
        output_schema: { 'type' => 'object' },
        risk_level: 'high',
        confirmation_mode: 'required',
        handler_method: :member_remove
      }
    ].freeze

    def tool_metadata
      TOOL_CATALOG.map { |tool| tool.except(:handler_method) }
    end

    def definitions(handlers:)
      TOOL_CATALOG.map do |tool|
        Registry::ToolDefinition.new(
          name: tool[:name],
          description: tool[:description],
          input_schema: tool[:input_schema],
          output_schema: tool[:output_schema],
          risk_level: tool[:risk_level],
          confirmation_mode: tool[:confirmation_mode],
          handler: ->(arguments:) { handlers.public_send(tool[:handler_method], arguments:) }
        )
      end
    end
  end
end
