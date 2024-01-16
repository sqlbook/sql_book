# frozen_string_literal: true

module App
  module DataSourcesHelper
    def tracking_code(data_source:)
      <<~HTML
        <script>
          (function(s,q,l,b,o,o,k){
            s._sbSettings={uuid:'#{data_source.external_uuid}'};
            e=q.getElementsByTagName('head')[0];
            a=q.createElement('script');
            a.src=l+s._sbSettings.uuid;
            e.appendChild(a);
          })(window,document,'https://cdn.sqlbook.com/1.0.0/script.js?');
        </script>
      HTML
    end

    def verifying?
      params['verifying'].present?
    end

    def verification_failed?
      params[:verification_attempt].to_i >= 5
    end

    def query_form_path(data_source:, query: nil)
      return app_data_source_queries_path(data_source) unless query

      app_data_source_query_path(data_source, query)
    end

    def query_form_method(query: nil)
      return :put if query

      :post
    end
  end
end
