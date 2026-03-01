# frozen_string_literal: true

require Rails.root.join('app/services/translations/database_backend').to_s

database_backend = Translations::DatabaseBackend.new
yaml_backend = I18n.backend

I18n.backend = I18n::Backend::Chain.new(database_backend, yaml_backend)
