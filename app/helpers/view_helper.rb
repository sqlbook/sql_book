# frozen_string_literal: true

module ViewHelper
  # Similar to the JS library of the same name - allows
  # you to pass a list of classnames, and a hash of
  # conditional classnames e.g
  #
  # class_names("class_1", conditional_class_1: condition_1, conditional_class_2: condition_2)
  #
  def class_names(*class_names, **conditional_class_names)
    conditionals = conditional_class_names.each_with_object([]) do |(key, value), memo|
      memo.push(key) if value
    end

    class_names.concat(conditionals).join(' ')
  end

  # Add a param to the url and preserve any that already
  # exist
  def add_params(params)
    { **request.params, **params }
  end
end
