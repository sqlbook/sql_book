# frozen_string_literal: true

module ViewHelper
  STEP_INDICATOR_STATES = {
    complete: 'complete',
    current: 'current',
    upcoming: 'upcoming'
  }.freeze

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

  def normalize_step_indicator(total_steps:, current_step:)
    normalized_total_steps = Integer(total_steps)
    normalized_current_step = Integer(current_step)

    raise ArgumentError, 'total_steps must be positive' if normalized_total_steps <= 0
    raise ArgumentError, 'current_step must be between 1 and total_steps' if normalized_current_step < 1 || normalized_current_step > normalized_total_steps

    [normalized_total_steps, normalized_current_step]
  end

  def step_indicator_step_state(step_number:, current_step:)
    return STEP_INDICATOR_STATES[:complete] if step_number < current_step
    return STEP_INDICATOR_STATES[:current] if step_number == current_step

    STEP_INDICATOR_STATES[:upcoming]
  end

  def step_indicator_connector_state(step_number:, current_step:)
    step_number < current_step ? STEP_INDICATOR_STATES[:complete] : STEP_INDICATOR_STATES[:upcoming]
  end

  def step_indicator_status_label(step_number:, total_steps:, current_step:)
    state = step_indicator_step_state(step_number:, current_step:)

    I18n.t(
      'shared.step_indicator.step_label',
      step_number:,
      total_steps:,
      status: I18n.t("shared.step_indicator.statuses.#{state}")
    )
  end
end
