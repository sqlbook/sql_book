# frozen_string_literal: true

namespace :chat do # rubocop:disable Metrics/BlockLength
  desc 'Audit app.workspaces.chat locale usage and chat-visible hardcoded strings'
  task audit_copy_surface: :environment do
    audit = Chat::CopyAudit.new
    output_path = ENV['OUTPUT'].presence
    report = audit.report
    serialized = report.to_yaml

    if output_path.present?
      absolute_path = Rails.root.join(output_path)
      File.write(absolute_path, serialized)
      puts "Wrote chat copy audit to #{absolute_path}"
    else
      puts serialized
    end

    puts
    puts "Locale leaf keys: #{report.dig('summary', 'locale_leaf_count')}"
    puts "Unclassified keys: #{report.dig('summary', 'unclassified_key_count')}"
    puts "Deprecated namespace consumers: #{report.dig('summary', 'deprecated_consumer_count')}"
    puts "Hardcoded strings inventoried: #{report.dig('summary', 'hardcoded_string_count')}"
  end

  desc 'Enforce the retained chat locale surface and prevent deprecated namespace drift'
  task enforce_copy_contract: :environment do
    audit = Chat::CopyAudit.new
    failures = []

    if audit.unclassified_keys.any?
      failures << "Unclassified chat locale keys: #{audit.unclassified_keys.map { |entry| entry['key'] }.join(', ')}"
    end

    if audit.keys_outside_retained_namespaces.any?
      failures << [
        'Chat locale keys outside retained namespaces:',
        audit.keys_outside_retained_namespaces.map { |entry| entry['key'] }.join(', ')
      ].join(' ')
    end

    if audit.deprecated_namespace_consumers.any?
      failures << [
        'Deprecated chat locale namespaces still referenced in app code:',
        audit.deprecated_namespace_consumers.map { |entry| "#{entry['file']}:#{entry['line']}" }.join(', ')
      ].join(' ')
    end

    next if failures.empty?

    abort(failures.join("\n"))
  end
end
