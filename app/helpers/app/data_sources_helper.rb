# frozen_string_literal: true

module App
  module DataSourcesHelper
    def tracking_code
      <<~HTML
        <script>
          console.log('Tracking code goes here');
        </script>
      HTML
    end
  end
end
