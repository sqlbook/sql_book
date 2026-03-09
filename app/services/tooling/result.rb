# frozen_string_literal: true

module Tooling
  Result = Struct.new(:status, :message, :data, :error_code, keyword_init: true)
end
