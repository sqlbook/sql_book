# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ToastsHelper, type: :helper do
  describe '#toast_action_href' do
    it 'prefers path for internal app links' do
      expect(helper.toast_action_href({ path: '/app/workspaces' })).to eq('/app/workspaces')
      expect(helper.toast_action_href({ path: 'app/workspaces' })).to eq('/app/workspaces')
    end

    it 'normalizes sqlbook absolute links to relative paths' do
      expect(helper.toast_action_href({ href: 'https://staging.sqlbook.com/app/workspaces?tab=general' }))
        .to eq('/app/workspaces?tab=general')
      expect(helper.toast_action_href({ href: 'https://sqlbook.com/auth/login' }))
        .to eq('/auth/login')
    end

    it 'keeps external links as absolute URLs' do
      expect(helper.toast_action_href({ href: 'https://help.example.com/article-1' }))
        .to eq('https://help.example.com/article-1')
    end
  end
end
