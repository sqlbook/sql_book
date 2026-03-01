# frozen_string_literal: true

class TranslationValue < ApplicationRecord
  SUPPORTED_LOCALES = %w[en es].freeze

  belongs_to :translation_key
  belongs_to :updated_by, class_name: 'User', optional: true
  has_many :translation_value_revisions, dependent: :destroy

  validates :locale, presence: true, inclusion: { in: SUPPORTED_LOCALES }
  validates :source, presence: true
  validates :translation_key_id, uniqueness: { scope: :locale }
end
