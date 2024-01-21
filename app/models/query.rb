# frozen_string_literal: true

class Query < ApplicationRecord
  belongs_to :data_source

  belongs_to :author,
             class_name: 'User',
             primary_key: :id

  belongs_to :last_updated_by,
             class_name: 'User',
             primary_key: :id,
             optional: true

  def query_result
    @query_result ||= QueryService.new(query: self).execute
  end
end
