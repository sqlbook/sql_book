# frozen_string_literal: true

module ApplicationHelper
  # TODO: Not sure where these should live, but
  # they are useful to have on every page
  include BreadcrumbsHelper
  include PageHelper
  include TabsHelper
  include ViewHelper
end
