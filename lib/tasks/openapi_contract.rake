# frozen_string_literal: true

require 'json'

namespace :openapi do
  desc 'Validate OpenAPI contract shape and required paths'
  task validate: :environment do
    path = Rails.root.join('config/openapi/v1.json')
    spec = JSON.parse(path.read)

    required_paths = [
      '/api/v1/workspaces/{workspace_id}',
      '/api/v1/workspaces/{workspace_id}/members',
      '/api/v1/workspaces/{workspace_id}/members/resend-invite',
      '/api/v1/workspaces/{workspace_id}/members/{id}/role',
      '/api/v1/workspaces/{workspace_id}/members/{id}'
    ]

    missing_paths = required_paths - spec.fetch('paths', {}).keys
    raise "OpenAPI spec missing required paths: #{missing_paths.join(', ')}" if missing_paths.any?

    unless spec['openapi'].to_s.start_with?('3.')
      raise "OpenAPI version must be 3.x, got: #{spec['openapi'].inspect}"
    end

    puts "OpenAPI contract valid: #{path}"
  end
end
