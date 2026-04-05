# frozen_string_literal: true

class QueryGroup < ApplicationRecord
  belongs_to :workspace

  has_many :query_group_memberships,
           dependent: :destroy

  has_many :queries,
           through: :query_group_memberships

  normalizes :name, with: ->(value) { QueryGroup.normalize_name(value) }

  validates :name,
            presence: true,
            uniqueness: {
              scope: :workspace_id,
              case_sensitive: false
            }

  scope :alphabetical, lambda {
    lower_name = Arel::Nodes::NamedFunction.new('LOWER', [arel_table[:name]])
    order(lower_name.asc, :id)
  }

  scope :named, lambda { |value|
    normalized_name = QueryGroup.normalize_name(value)

    if normalized_name.blank?
      none
    else
      lower_name = Arel::Nodes::NamedFunction.new('LOWER', [arel_table[:name]])
      where(lower_name.eq(normalized_name.downcase))
    end
  }

  class << self
    def normalize_name(value)
      value.to_s.squish.presence
    end

    def fetch_or_create!(workspace:, name:)
      normalized_name = normalize_name(name)
      raise ActiveRecord::RecordInvalid, new if normalized_name.blank?

      existing_group = workspace.query_groups.named(normalized_name).first
      return existing_group if existing_group

      workspace.query_groups.create!(name: normalized_name)
    rescue ActiveRecord::RecordNotUnique
      workspace.query_groups.named(normalized_name).first!
    end
  end
end
