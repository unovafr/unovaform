# frozen_string_literal: true

module UnovaForm
  module FieldTypes
    class Hidden < Base
      INPUT_TYPE = :hidden

      VALIDATORS = {}.freeze
    end
  end
end