# frozen_string_literal: true

class TranslationValueRevision < ApplicationRecord
  belongs_to :translation_value
  belongs_to :changed_by, class_name: 'User', optional: true

  validates :locale, presence: true
  validates :change_source, presence: true
end
