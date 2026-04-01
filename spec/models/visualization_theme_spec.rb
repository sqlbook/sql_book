# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VisualizationTheme, type: :model do
  describe 'workspace default handling' do
    it 'unsets other workspace defaults when a new default theme is saved' do
      workspace = create(:workspace)
      original_default = create(:visualization_theme, workspace:, default: true, name: 'Original default')
      new_default = create(:visualization_theme, workspace:, default: false, name: 'New default')

      new_default.update!(default: true)

      expect(new_default.reload.default).to be(true)
      expect(original_default.reload.default).to be(false)
    end
  end
end
