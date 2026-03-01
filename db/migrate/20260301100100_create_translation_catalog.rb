# frozen_string_literal: true

class CreateTranslationCatalog < ActiveRecord::Migration[8.0]
  def change
    create_table :translation_keys do |table|
      table.string :key, null: false
      table.text :notes
      table.text :area_tags, array: true, default: [], null: false
      table.text :type_tags, array: true, default: [], null: false
      table.jsonb :used_in, default: [], null: false
      table.string :content_scope, default: 'system', null: false

      table.timestamps
    end

    add_index :translation_keys, :key, unique: true

    create_table :translation_values do |table|
      table.references :translation_key, null: false, foreign_key: true
      table.string :locale, null: false
      table.text :value
      table.string :source, null: false, default: 'seed'
      table.references :updated_by, null: true, foreign_key: { to_table: :users }

      table.timestamps
    end

    add_index :translation_values, %i[translation_key_id locale], unique: true
    add_index :translation_values, :locale

    create_table :translation_value_revisions do |table|
      table.references :translation_value, null: false, foreign_key: true
      table.string :locale, null: false
      table.text :old_value
      table.text :new_value
      table.references :changed_by, null: true, foreign_key: { to_table: :users }
      table.string :change_source, null: false, default: 'manual'

      table.timestamps
    end

    add_index :translation_value_revisions, :locale
  end
end
