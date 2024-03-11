# frozen_string_literal: true

class DataSourceMailer < ApplicationMailer
  def destroy(deleted_by:, data_source:, member:)
    @deleted_by = deleted_by
    @data_source = data_source

    subject = I18n.t('mailers.data_source.subjects.destroy', workspace_name: data_source.workspace.name)

    mail(to: member.user.email, subject:)
  end
end
