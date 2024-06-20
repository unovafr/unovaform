module UnovaForm
  module Classes
    # @!attribute [r] type
    #   @return [Class<UnovaForm::FieldTypes::Base>] type field type that will be used to determine type validators and field tag type
    # @!attribute [r] validators
    #   @return [Hash{Symbol => Object}, NilClass] validators validators hash that will be given to a #validates method
    # @!attribute [r] has_confirmation
    #   @return [TrueClass, FalseClass] use_type_validators will add a <field_name>_confirmation field validation, you must add the field yourself
    # @!attribute [r] use_type_validators
    #   @return [TrueClass, FalseClass] has_confirmation define if field will use validators defined in #type, can be override by elements in #validators
    # @!attribute [r] required
    #   @return [TrueClass, FalseClass] required define if field is required, will add required attribute to tag, and a presence validator.
    # @!attribute [r] required_if_persisted
    #   @return [TrueClass, FalseClass] required_if_persisted if false, if #required is true, will only add required tag and presence validator if model is not persisted
    # @!attribute [r] options
    #   @return [Array<Hash{Symbol => String, FalseClass, TrueClass}>, Proc{String => Array<Hash{Symbol => String, TrueClass, FalseClass}>}, NilClass] options used to transform field into selector, options must have format: [ { value: String, label: String, disabled: Boolean | nil, selected: Boolean | nil } ] or -> (String value) { [ { value: String, label: String, disabled: Boolean | nil, selected: Boolean | nil } ] }
    # @!attribute [r] multiple
    #   @return [TrueClass, FalseClass] multiple transform selector into a multiselect
    # @!attribute [r] additional_options
    #  @return [Hash{Symbol => Hash{Symbol => String}}] additional options that will be passed to the field tag
    # noinspection RubyTooManyInstanceVariablesInspection
    class Field

      attr_reader :type, :validators, :has_confirmation, :use_type_validators, :required, :required_if_persisted, :options, :multiple, :additional_options

      # @return [Hash{Symbol => Object}]
      def all_validators
        @all_validators
      end

      ##
      # @param [Class<UnovaForm::FieldTypes::Base>] field_type field type that will be used to determine type validators and field tag type
      # @param [Hash{Symbol => Object}, NilClass] validators validators hash that will be given to a #validates method
      # @param [TrueClass, FalseClass] use_type_validators will add a <field_name>_confirmation field validation, you must add the field yourself
      # @param [TrueClass, FalseClass] has_confirmation define if field will use validators defined in #type, can be override by elements in #validators
      # @param [TrueClass, FalseClass] required define if field is required, will add required attribute to tag, and a presence validator.
      # @param [TrueClass, FalseClass] required_if_persisted if false, if #required is true, will only add required tag and presence validator if model is not persisted
      # @param [Array<Hash{Symbol => String, TrueClass, FalseClass}>, Proc<Array<Hash{Symbol => String, TrueClass, FalseClass}>>, NilClass] options used to transform field into selector, options must have format: [ { value: String, label: String, disabled: Boolean | nil, selected: Boolean | nil } ] or -> (String value) { [ { value: String, label: String, disabled: Boolean | nil, selected: Boolean | nil } ] }
      # @option options [String] :value value of option tag
      # @option options [String] :label label (shown text) of option tag
      # @option options [TrueClass, FalseClass] :selected if option tag is selected
      # @option options [TrueClass, FalseClass] :disabled if option tag is disabled
      # @param [TrueClass, FalseClass] multiple transform selector into a multiselect
      # @param [Hash{Symbol => Hash{Symbol => String}}] additional_options additional options that will be passed to the field tag
      # @return [void]
      # @return [void]
      def initialize(field_type, validators, has_confirmation, use_type_validators, required, required_if_persisted, options, multiple, **additional_options)
        @type = field_type.is_a?(UnovaForm::FieldTypes::Base) ? field_type : "UnovaForm::FieldTypes::#{field_type.to_s.camelize}".constantize
        @validators = validators
        @has_confirmation = has_confirmation
        @use_type_validators = use_type_validators
        @required = required
        @required_if_persisted = required_if_persisted
        @options = options
        @multiple = multiple
        @additional_options = additional_options
        set_all_validators
      end

      # @return [Field]
      def dup
        Field.new(type, validators.deep_dup, has_confirmation, use_type_validators, required, required_if_persisted, options.deep_dup, multiple)
      end

      private

        # @return [void]
        def set_all_validators
          @all_validators = type::VALIDATORS.deep_merge(validators) if use_type_validators && validators.present?
          @all_validators = type::VALIDATORS.deep_dup if use_type_validators && validators.nil?
          @all_validators ||= validators || {}
        end
    end
  end
end