# frozen_string_literal: true

module DataSources
  module Connectors
    class BaseConnector
      class ConnectionError < StandardError; end
      class QueryError < StandardError
        attr_reader :code

        def initialize(message, code: nil)
          super(message)
          @code = code
        end
      end
      class UnsupportedSourceTypeError < StandardError; end

      attr_reader :data_source

      def initialize(data_source: nil, **)
        @data_source = data_source
      end

      def validate_connection!
        raise NotImplementedError
      end

      def list_tables(**)
        raise NotImplementedError
      end

      def execute_readonly(sql:, **)
        raise NotImplementedError
      end
    end
  end
end
