# frozen_string_literal: true

module QueryEditor
  module RunToken
    module_function

    def issue(data_source_id:, sql:)
      verifier.generate(
        {
          fingerprint: Queries::Fingerprint.build(data_source_id:, sql:),
          issued_at: Time.current.to_i
        }
      )
    end

    def valid?(token:, data_source_id:, sql:)
      payload = verifier.verified(token.to_s)
      return false unless payload.is_a?(Hash)

      (payload['fingerprint'] || payload[:fingerprint]) == Queries::Fingerprint.build(data_source_id:, sql:)
    end

    def verifier
      Rails.application.message_verifier('query_editor_run_token')
    end
  end
end
