# frozen_string_literal: true

module ChatMarkdownHelper
  MARKDOWN_ALLOWED_TAGS = %w[
    p br ul ol li strong em a code pre blockquote div table thead tbody tr th td
  ].freeze
  MARKDOWN_ALLOWED_ATTRIBUTES = %w[href title rel class].freeze
  MARKDOWN_EXTENSIONS = {
    autolink: true,
    strikethrough: true,
    table: true,
    tagfilter: true
  }.freeze

  def render_chat_markdown(content)
    return ''.html_safe if content.to_s.strip.blank?

    rendered = Commonmarker.to_html(
      content.to_s,
      options: {
        extension: MARKDOWN_EXTENSIONS
      }
    )

    sanitized_markdown(rendered)
  end

  private

  def sanitized_markdown(rendered_html)
    fragment = Nokogiri::HTML::DocumentFragment.parse(rendered_html)

    fragment.css('table').each do |table|
      wrapper = Nokogiri::XML::Node.new('div', fragment)
      wrapper['class'] = 'chat-markdown-table-wrap'
      table.replace(wrapper)
      wrapper.add_child(table)
    end

    fragment.css('a[href]').each do |link|
      href = link['href'].to_s
      unless href.start_with?('http://', 'https://', 'mailto:')
        link.replace(link.text)
        next
      end

      link['rel'] = 'nofollow noopener noreferrer'
    end

    sanitize(fragment.to_html, tags: MARKDOWN_ALLOWED_TAGS, attributes: MARKDOWN_ALLOWED_ATTRIBUTES)
  end
end
