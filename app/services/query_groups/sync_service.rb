# frozen_string_literal: true

module QueryGroups
  class SyncService
    def initialize(query:, workspace:, names:)
      @query = query
      @workspace = workspace
      @names = Array(names)
    end

    def call
      target_groups = normalized_names.map do |name|
        QueryGroup.fetch_or_create!(workspace:, name:)
      end

      sync_memberships!(target_groups:)
      query.reload
    end

    private

    attr_reader :query, :workspace, :names

    def normalized_names
      @normalized_names ||= names.filter_map { |name| QueryGroup.normalize_name(name) }
        .uniq(&:downcase)
    end

    def sync_memberships!(target_groups:)
      target_group_ids = target_groups.map(&:id)

      query.query_group_memberships.includes(:query_group).find_each do |membership|
        next if target_group_ids.include?(membership.query_group_id)

        membership.destroy!
      end

      target_groups.each do |group|
        query.query_group_memberships.find_or_create_by!(query_group: group)
      end
    end
  end
end
