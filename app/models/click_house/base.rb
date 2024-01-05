# frozen_string_literal: true

module ClickHouse
  class Base < ApplicationRecord
    self.abstract_class = true

    class << self
      def agent
        ClickHouse.connection
      end

      def insert(*, &)
        agent.insert(table_name, *, &)
      end

      def select_one
        agent.select_one(current_scope.to_sql)
      end

      def select_value
        agent.select_value(current_scope.to_sql)
      end

      def select_all
        agent.select_all(current_scope.to_sql)
      end

      def explain
        agent.explain(current_scope.to_sql)
      end
    end
  end
end
