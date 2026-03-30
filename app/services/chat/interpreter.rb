# frozen_string_literal: true

module Chat
  class Interpreter
    def initialize(runtime_service:, intent_reconciler:)
      @runtime_service = runtime_service
      @intent_reconciler = intent_reconciler
    end

    def call
      decision = runtime_service.call
      intent_reconciler.reconcile(decision:)
    end

    private

    attr_reader :runtime_service, :intent_reconciler
  end
end
