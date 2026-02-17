# frozen_string_literal: true

module ToastsHelper
  def toast_action_href(action)
    path = action['path'] || action[:path]
    return normalized_internal_path(path) if path.present?

    href = action['href'] || action[:href]
    return '#' if href.blank?

    rewrite_internal_href(href)
  rescue URI::InvalidURIError
    href
  end

  private

  def normalized_internal_path(path)
    value = path.to_s
    value.start_with?('/') ? value : "/#{value}"
  end

  def internal_host?(host)
    return true if host == Rails.application.config.x.app_host

    host == 'sqlbook.com' || host.end_with?('.sqlbook.com')
  end

  def rewrite_internal_href(href)
    parsed = URI.parse(href.to_s)
    return href if parsed.host.blank?
    return parsed.request_uri if internal_host?(parsed.host)

    href
  end
end
