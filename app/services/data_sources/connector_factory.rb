# frozen_string_literal: true

module DataSources
  module ConnectorFactory
    module_function

    def build(data_source: nil, source_type: nil, attributes: {})
      resolved_source_type = source_type.presence || data_source&.source_type

      case resolved_source_type.to_s
      when 'first_party_capture'
        Connectors::FirstPartyCaptureConnector.new(data_source:)
      when 'postgres'
        Connectors::PostgresConnector.new(data_source:, connection_attributes: attributes)
      else
        raise Connectors::BaseConnector::UnsupportedSourceTypeError, resolved_source_type.to_s
      end
    end
  end
end
