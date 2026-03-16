# frozen_string_literal: true

module Chat
  ActionIntent = Struct.new(
    :assistant_message,
    :action_type,
    :payload,
    :missing_information,
    :finalize_without_tools,
    :tool_definition,
    :source,
    :confidence,
    keyword_init: true
  ) do
    def confirmation_required?
      tool_definition.to_h[:confirmation_mode].to_s == 'required'
    end

    def read?
      tool_definition.to_h[:risk_level].to_s == 'read'
    end

    def write?
      tool_definition.present? && !read?
    end

    def missing?
      missing_information.any?
    end
  end
end
