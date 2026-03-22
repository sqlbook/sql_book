# frozen_string_literal: true

module App
  module Workspaces
    class DataSourcesController < ApplicationController # rubocop:disable Metrics/ClassLength
      WIZARD_CACHE_TTL = 1.hour
      WIZARD_SESSION_KEY_PREFIX = 'data_source_wizard_state'
      WIZARD_PARAM_KEYS = %i[
        source_type
        name
        database_type
        host
        port
        database_name
        username
        password
        ssl_mode
        extract_category_values
      ].freeze
      DATA_SOURCE_PARAM_KEYS = %i[
        url
        host
        port
        database_name
        username
        password
        ssl_mode
        extract_category_values
      ].freeze

      before_action :require_authentication!
      before_action :authorize_data_source_view_access!, only: %i[index show]
      before_action :authorize_data_source_manage_access!, except: %i[index show]

      def index
        @workspace = workspace
        @data_sources = data_sources.order(source_type: :asc, created_at: :asc)
        @data_sources_stats = DataSourcesStatsService.new(data_sources: @data_sources)
        @selected_data_source = selected_data_source
        prepare_selected_data_source_panel if @selected_data_source
      end

      def show
        redirect_to app_workspace_data_sources_path(
          workspace,
          data_source_id: data_source.id,
          tab: params[:tab],
          confirm_delete: params[:confirm_delete]
        )
      end

      def new
        @workspace = workspace
        prepare_new_view(step: requested_step)
      end

      def validate_connection
        @workspace = workspace
        @wizard_state = merged_wizard_state(wizard_form_params.to_h)

        return render_invalid_wizard_step_two unless wizard_step_two_valid?(@wizard_state)

        validation = validate_postgres_connection(@wizard_state)
        return handle_successful_validation(validation) if validation.success?

        render_connection_validation_failure(validation)
      end

      def create
        return create_capture_source if data_source_params[:url].present?

        @workspace = workspace
        result = create_postgres_data_source
        return handle_postgres_create_success(result) if result.success?

        handle_postgres_create_failure(result)
      end

      def update
        @workspace = workspace
        @selected_data_source = data_source

        return handle_postgres_update if @selected_data_source.external_database?
        return redirect_to_data_source unless capture_update_requested?
        return redirect_to_data_source if update_capture_source

        handle_invalid_data_source_update(@selected_data_source)
      end

      def destroy
        send_data_source_destroy_mailer
        data_source.destroy!
        redirect_to app_workspace_data_sources_path(workspace)
      end

      private

      def workspace
        @workspace ||= find_workspace_for_current_user!(param_key: :workspace_id)
      end

      def data_sources
        @data_sources ||= workspace.data_sources.includes(:queries)
      end

      def data_source
        @data_source ||= workspace.data_sources.find(params[:id])
      end

      def selected_data_source
        return if params[:data_source_id].blank?

        data_sources.find(params[:data_source_id])
      end

      def requested_step
        step = params[:step].to_i
        step.positive? ? step : 1
      end

      def prepare_new_view(step:)
        clear_wizard_state! if step == 1
        repopulate_available_tables! if step == 3
        @wizard_step = step
        @wizard_state = wizard_state
        @wizard_step_two_errors ||= {}
        @wizard_step_two_connection_error ||= nil
        @available_tables = Array(@wizard_state['available_tables'])
        return unless @wizard_step == 3 && @available_tables.empty?

        @wizard_step = 2
      end

      def data_source_params
        params.permit(*DATA_SOURCE_PARAM_KEYS, selected_tables: [])
      end

      def wizard_form_params
        params.permit(*WIZARD_PARAM_KEYS, selected_tables: [])
      end

      def postgres_create_attributes
        current_state = merged_wizard_state(wizard_form_params.to_h)

        {
          name: current_state['name'],
          host: current_state['host'],
          port: current_state['port'],
          database_name: current_state['database_name'],
          username: current_state['username'],
          password: decrypted_wizard_password(current_state),
          ssl_mode: current_state['ssl_mode'],
          extract_category_values: current_state['extract_category_values'],
          selected_tables: Array(wizard_form_params[:selected_tables])
        }
      end

      def wizard_connection_attributes(state)
        {
          host: state['host'],
          port: state['port'],
          database_name: state['database_name'],
          username: state['username'],
          password: decrypted_wizard_password(state),
          ssl_mode: state['ssl_mode'],
          extract_category_values: state['extract_category_values']
        }
      end

      def merged_wizard_state(overrides = {})
        normalized_overrides = normalize_wizard_overrides(overrides)

        wizard_state.merge(normalized_overrides).merge('source_type' => 'postgres')
      end

      def wizard_state
        base_state
          .merge(wizard_session_state)
          .merge((Rails.cache.read(wizard_cache_key) || {}).deep_stringify_keys)
      end

      def base_state
        {
          'source_type' => 'postgres',
          'database_type' => nil,
          'port' => DataSource::POSTGRES_DEFAULT_PORT,
          'ssl_mode' => DataSource::POSTGRES_DEFAULT_SSL_MODE,
          'extract_category_values' => false,
          'encrypted_password' => nil,
          'selected_tables' => [],
          'available_tables' => []
        }
      end

      def persist_wizard_state!(state)
        normalized_state = state.deep_stringify_keys

        session[wizard_session_key] = normalized_state.except('available_tables')
        Rails.cache.write(
          wizard_cache_key,
          normalized_state.slice('available_tables'),
          expires_in: WIZARD_CACHE_TTL
        )
      end

      def clear_wizard_state!
        session.delete(wizard_session_key)
        Rails.cache.delete(wizard_cache_key)
      end

      def wizard_cache_key
        token = session[:data_source_wizard_token]
        token ||= SecureRandom.hex(16)
        session[:data_source_wizard_token] = token

        [
          'data_source_wizard',
          current_user.id,
          workspace.id,
          token
        ].join('::')
      end

      def wizard_session_key
        "#{WIZARD_SESSION_KEY_PREFIX}::#{workspace.id}"
      end

      def wizard_session_state
        session.fetch(wizard_session_key, {}).deep_stringify_keys
      end

      def create_capture_source
        data_source = DataSource.new(
          url: params[:url],
          name: params[:url],
          workspace:,
          source_type: :first_party_capture
        )
        return handle_invalid_data_source_create(data_source) unless data_source.save

        redirect_to app_workspace_data_source_set_up_index_path(workspace, data_source)
      end

      def capture_update_requested?
        data_source.capture_source? && data_source_params[:url]
      end

      def update_capture_source
        data_source.url = data_source_params[:url]
        data_source.name = data_source_params[:url]
        data_source.verified_at = nil
        data_source.save
      end

      def redirect_to_data_source
        redirect_to app_workspace_data_source_path(workspace, data_source)
      end

      def send_data_source_destroy_mailer
        workspace.members.each do |member|
          DataSourceMailer.destroy(deleted_by: current_user, data_source:, member:).deliver_now
        end
      end

      def authorize_data_source_view_access!
        return if can_view_data_sources?(workspace:)

        deny_workspace_access!(workspace:)
      end

      def authorize_data_source_manage_access!
        return if can_manage_data_sources?(workspace:)

        deny_workspace_access!(workspace:)
      end

      def handle_invalid_data_source_create(data_source)
        flash[:alert] = data_source.errors.full_messages.first
        redirect_to new_app_workspace_data_source_path(workspace)
      end

      def handle_invalid_data_source_update(data_source)
        flash[:alert] = data_source.errors.full_messages.first
        redirect_to app_workspace_data_source_path(workspace, data_source)
      end

      def handle_postgres_update
        result = update_postgres_data_source
        return handle_postgres_update_success(result) if result.success?

        handle_postgres_update_failure(result)
      end

      def update_postgres_data_source
        ::DataSources::UpdatePostgresDataSourceService.new(
          data_source: @selected_data_source,
          attributes: postgres_update_attributes
        ).call
      end

      def postgres_update_attributes
        {
          host: data_source_params[:host],
          port: data_source_params[:port],
          database_name: data_source_params[:database_name],
          username: data_source_params[:username],
          password: data_source_params[:password],
          ssl_mode: data_source_params[:ssl_mode],
          extract_category_values: data_source_params[:extract_category_values],
          selected_tables: Array(data_source_params[:selected_tables])
        }
      end

      def handle_postgres_update_success(_result)
        flash[:toast] = {
          type: 'success',
          title: I18n.t('app.workspaces.data_sources.toasts.updated.title'),
          body: I18n.t(
            'app.workspaces.data_sources.toasts.updated.body',
            name: @selected_data_source.display_name
          )
        }
        redirect_to app_workspace_data_sources_path(workspace, data_source_id: @selected_data_source.id)
      end

      def handle_postgres_update_failure(result)
        @data_sources = data_sources.order(source_type: :asc, created_at: :asc)
        @data_sources_stats = DataSourcesStatsService.new(data_sources: @data_sources)
        @selected_data_source_errors = {}
        @selected_data_source_connection_error = nil
        populate_selected_data_source_form_state
        @selected_data_source_available_tables = normalize_table_groups(result.available_tables)
        apply_postgres_update_errors(result)

        render :index, status: :unprocessable_entity
      end

      def prepare_selected_data_source_panel
        @selected_data_source_errors ||= {}
        @selected_data_source_connection_error ||= nil
        populate_selected_data_source_form_state
        return if instance_variable_defined?(:@selected_data_source_available_tables)

        @selected_data_source_available_tables = selected_data_source_available_tables(@selected_data_source)
      end

      def populate_selected_data_source_form_state
        @selected_data_source_form_state = {
          'host' => selected_data_source_form_value(:host, @selected_data_source.host),
          'port' => selected_data_source_form_value(:port, @selected_data_source.port),
          'database_name' => selected_data_source_form_value(:database_name, @selected_data_source.database_name),
          'username' => selected_data_source_form_value(:username, @selected_data_source.username),
          'ssl_mode' => selected_data_source_form_value(:ssl_mode, @selected_data_source.ssl_mode),
          'extract_category_values' => extract_category_values_param,
          'selected_tables' => selected_tables_param
        }
      end

      def selected_data_source_available_tables(selected_source)
        normalize_table_groups(
          selected_source.connector.list_tables(include_columns: false)
        )
      rescue ::DataSources::Connectors::BaseConnector::ConnectionError
        @selected_data_source_connection_error = I18n.t('app.workspaces.data_sources.validation.connection_failed')
        fallback_available_tables_for(selected_source)
      end

      def normalize_table_groups(groups)
        Array(groups).map(&:deep_symbolize_keys)
      end

      def fallback_available_tables_for(selected_source)
        selected_source.selected_tables
          .group_by { |table_name| table_name.split('.', 2).first }
          .map do |schema, table_names|
          {
            schema:,
            tables: table_names.map do |table_name|
              {
                name: table_name.split('.', 2).last,
                qualified_name: table_name
              }
            end
          }
        end
      end

      def selected_tables_param
        return Array(data_source_params[:selected_tables]).map(&:to_s) if params.key?(:selected_tables)

        @selected_data_source.selected_tables
      end

      def extract_category_values_param
        if params.key?(:extract_category_values)
          ActiveModel::Type::Boolean.new.cast(data_source_params[:extract_category_values])
        else
          @selected_data_source.extract_category_values?
        end
      end

      def apply_postgres_update_errors(result)
        return apply_postgres_connection_error(result) if result.error_code == 'connection_failed'
        return apply_postgres_validation_errors if result.error_code == 'validation_error'

        @selected_data_source_errors = { 'selected_tables' => [result.message] }
      end

      def apply_postgres_connection_error(result)
        @selected_data_source_connection_error = result.message
        return unless @selected_data_source_available_tables.empty?

        @selected_data_source_available_tables = fallback_available_tables_for(@selected_data_source)
      end

      def apply_postgres_validation_errors
        @selected_data_source_errors = @selected_data_source.errors.to_hash(true)
      end

      def selected_data_source_form_value(param_key, current_value)
        data_source_params[param_key].presence || current_value
      end

      def wizard_step_two_valid?(state)
        return false unless supported_database_type_selected?(state)

        preview = build_postgres_preview_data_source(state)
        preview.connection_password = decrypted_wizard_password(state)

        return true if preview.valid?

        @wizard_step_two_errors = wizard_step_two_error_messages(preview)
        false
      end

      def normalize_wizard_overrides(overrides)
        normalized_overrides = overrides.stringify_keys.except('password')

        password = overrides[:password] || overrides['password']
        if password.present?
          normalized_overrides['encrypted_password'] = encrypted_password_value(password)
        elsif normalized_overrides.key?('encrypted_password')
          normalized_overrides['encrypted_password'] = normalized_overrides['encrypted_password'].presence
        end

        normalized_overrides
      end

      def decrypted_wizard_password(state)
        encrypted_password = state['encrypted_password'].presence
        return nil if encrypted_password.blank?

        DataSource.connection_password_encryptor.decrypt_and_verify(encrypted_password)
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        nil
      end

      def repopulate_available_tables!
        current_state = wizard_state
        return if Array(current_state['available_tables']).any?
        return unless wizard_step_two_valid_for_recovery?(current_state)

        validation = ::DataSources::ConnectionValidationService.new(
          source_type: 'postgres',
          attributes: wizard_connection_attributes(current_state)
        ).call
        return unless validation.success?

        persist_wizard_state!(
          current_state.merge(
            'available_tables' => validation.available_tables,
            'last_checked_at' => validation.checked_at&.iso8601
          )
        )
      end

      def wizard_step_two_valid_for_recovery?(state)
        state['database_type'] == 'postgres' &&
          state['name'].present? &&
          state['host'].present? &&
          state['database_name'].present? &&
          state['username'].present? &&
          decrypted_wizard_password(state).present?
      end

      def supported_database_type_selected?(state)
        database_type = state['database_type'].to_s

        if database_type.blank?
          @wizard_step_two_errors = {
            'database_type' => [I18n.t('app.workspaces.data_sources.validation.database_type_required')]
          }
          return false
        end

        return true if database_type == 'postgres'

        @wizard_step_two_errors = {
          'database_type' => [I18n.t('app.workspaces.data_sources.validation.unsupported_database_type')]
        }
        false
      end

      def validate_postgres_connection(state)
        ::DataSources::ConnectionValidationService.new(
          source_type: 'postgres',
          attributes: wizard_connection_attributes(state)
        ).call
      end

      def render_invalid_wizard_step_two
        persist_wizard_state!(wizard_state_without_validation_metadata(@wizard_state))
        prepare_new_view(step: 2)
        render :new, status: :unprocessable_entity
      end

      def handle_successful_validation(validation)
        persist_wizard_state!(
          @wizard_state.merge(
            'available_tables' => validation.available_tables,
            'last_checked_at' => validation.checked_at&.iso8601
          )
        )
        redirect_to new_app_workspace_data_source_path(@workspace, step: 3)
      end

      def render_connection_validation_failure(validation)
        @wizard_step_two_connection_error = validation.message
        persist_wizard_state!(wizard_state_without_validation_metadata(@wizard_state))
        prepare_new_view(step: 2)
        render :new, status: :unprocessable_entity
      end

      def create_postgres_data_source
        ::DataSources::CreatePostgresDataSourceService.new(
          workspace: @workspace,
          attributes: postgres_create_attributes
        ).call
      end

      def handle_postgres_create_success(result)
        clear_wizard_state!
        flash[:toast] = {
          type: 'success',
          title: I18n.t('app.workspaces.data_sources.toasts.created.title'),
          body: I18n.t(
            'app.workspaces.data_sources.toasts.created.body',
            name: result.data_source.display_name
          )
        }
        redirect_to app_workspace_data_sources_path(@workspace)
      end

      def handle_postgres_create_failure(result)
        @wizard_step_two_connection_error = result.message if result.error_code == 'connection_failed'
        flash.now[:alert] = result.message unless result.error_code == 'connection_failed'
        persist_wizard_state!(wizard_state_for_failed_create(result))
        prepare_new_view(step: result.error_code == 'connection_failed' ? 2 : 3)
        render :new, status: :unprocessable_entity
      end

      def wizard_state_for_failed_create(result)
        merged_wizard_state(wizard_form_params.to_h).merge(
          'available_tables' => result.available_tables,
          'selected_tables' => Array(wizard_form_params[:selected_tables]).map(&:to_s)
        )
      end

      def wizard_state_without_validation_metadata(state)
        state.except('available_tables', 'last_checked_at')
      end

      def build_postgres_preview_data_source(state)
        workspace.data_sources.new(
          name: state['name'],
          source_type: :postgres,
          status: :pending_setup,
          config: preview_config(state)
        )
      end

      def preview_config(state)
        {
          'host' => state['host'],
          'port' => state['port'],
          'database_name' => state['database_name'],
          'username' => state['username'],
          'ssl_mode' => state['ssl_mode'],
          'extract_category_values' => state['extract_category_values'],
          'selected_tables' => []
        }
      end

      def encrypted_password_value(password)
        DataSource.connection_password_encryptor.encrypt_and_sign(password)
      end

      def wizard_step_two_error_messages(preview)
        preview.errors.to_hash(true).each_with_object({}) do |(attribute, messages), errors|
          key = attribute.to_s == 'connection_password' ? 'password' : attribute.to_s
          errors[key] = Array(messages)
        end
      end
    end
  end
end
