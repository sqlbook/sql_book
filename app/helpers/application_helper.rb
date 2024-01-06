# frozen_string_literal: true

module ApplicationHelper
  # TODO: Not sure where these should live, but
  # they are useful to have on every page
  include PageHelper
  include TabsHelper
  include ViewHelper

  def sqlbook_tracking_script
    return '' unless Rails.env.development?

    <<~HTML
      <script>
        (function(s,q,l,b,o,o,k){
          s._sbSettings={uuid:'#{DataSource.first.external_uuid}'};
          e=q.getElementsByTagName('head')[0];
          a=q.createElement('script');
          a.src=l+s._sbSettings.uuid;
          e.appendChild(a);
        })(window,document,'http://localhost:3000/script.js?');
      </script>
    HTML
  end
end
