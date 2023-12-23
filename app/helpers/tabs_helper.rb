# frozen_string_literal: true

module TabsHelper
  def active_tab?(tab:, default_selected: false)
    return true if default_selected && params['tab'].nil?

    params['tab'] == tab
  end
end
