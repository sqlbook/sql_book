# frozen_string_literal: true

class Query < ApplicationRecord
  belongs_to :data_source

  def query_result
    @query_result ||= QueryService.new(query: self).execute
  end
end
