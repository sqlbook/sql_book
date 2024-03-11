# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/data_source
class DataSourcePreview < ActionMailer::Preview
  def destroy
    deleted_by = User.first
    data_source = DataSource.first
    DataSourceMailer.destroy(deleted_by:, data_source:, member: data_source.workspace.members.first)
  end
end
