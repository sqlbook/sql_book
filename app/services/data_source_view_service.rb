# frozen_string_literal: true

class DataSourceViewService
  def initialize(data_source:)
    @data_source = data_source
  end

  MODELS = [Click, PageView, Session].freeze

  def create!
    ConnectionHelper.with_database(:clickhouse) do
      MODELS.each do |model|
        sql = <<-SQL.squish
          CREATE VIEW IF NOT EXISTS #{view_name(model)} AS
          SELECT * FROM #{model.table_name} WHERE data_source_uuid = '#{data_source.external_uuid}'
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end

  def destroy!
    ConnectionHelper.with_database(:clickhouse) do
      MODELS.each do |model|
        sql = "DROP VIEW IF EXISTS #{view_name(model)}"
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end

  def exists?
    ConnectionHelper.with_database(:clickhouse) do
      MODELS.each do |model|
        sql = "SHOW VIEW #{view_name(model)}"
        ActiveRecord::Base.connection.execute(sql)
      end
    end

    true
  rescue ActiveRecord::ActiveRecordError
    false
  end

  private

  attr_reader :data_source

  def view_name(model)
    identifier = data_source.external_uuid.gsub('-', '') # the hyphens are not valid as table names
    "data_source_#{identifier}_#{model.table_name}"
  end
end
