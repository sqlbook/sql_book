# frozen_string_literal: true

namespace :readonly_events_user do
  desc 'Create the readonly user'
  task create: :environment do
    if EventRecord.connection.exec_query("SELECT * FROM pg_user WHERE usename = 'sql_book_readonly'").empty?
      EventRecord.connection.exec_query('CREATE ROLE sql_book_readonly WITH LOGIN PASSWORD NULL')
    end

    EventRecord.all_event_types.each do |event_type|
      EventRecord.connection.exec_query("GRANT SELECT ON #{event_type.table_name} TO sql_book_readonly")
    end
  end
end
