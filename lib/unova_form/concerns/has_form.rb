# frozen_string_literal: true

module UnovaForm
  module Concerns
    module HasForm
      # For this function to work properly, you need to include ActiveModel::Model
      # in your model +class+ before extending this concern.
      def self.extended(mod)

        mod.class_eval do
          def form_format(form_name = :base, nesteds: [], model_name: self.class.model_name.param_key, **options)
            all_validators = self.class.validators.select do |v|
              next false if v.options[:on] && !v.options[:on].include?(form_name)
              next false if v.options[:if] && !instance_exec(&v.options[:if])
              next false if v.options[:unless] && instance_exec(&v.options[:unless])
              true
            end
            @b = UnovaForm::Builder.new(model_name, self, nil, {})
            @b.send(:check_form, form_name)
            out = {
              model_name:,
              form_name: form_name,
              fields: {},
            }
            self.class.forms[form_name].fields.each do |field_name, field|
              validators = all_validators.select { |v| v.attributes.include?(field_name) }
              @b.instance_variable_set(:@current_method, field_name)
              @b.send(:current_field=, field)
              f = {
                type: @b.send(:current_tag_type),
                name: @b.send(:current_tag_name),
                label: @b.send(:current_human_name_for),
                placeholder: @b.send(:current_human_name_for, :placeholders),
                value: @b.send(:current_tag_type) == :time ? @b.send(:current_value)&.strftime("%H:%M:%S") : @b.send(:current_value),
                multiple: @b.send(:multiple?),
                additional_options: {
                  **@b.send(:parse_additional_options, @b.send(:current_field).additional_options).merge(
                    **@b.send(:parse_additional_options, options.except(:options_for) || {}),
                    **@b.send(:parse_additional_options, options.dig(:options_for, field_name) || {})
                  ),
                }
              }

              opts = @b.send(:current_options)
              f[:options] = opts if opts.present?

              f[:required] = validators.any? { |v| v.kind == :presence }

              f[:formats] = validators.select { |v| v.kind == :format }.map do |fv|
                {
                  with: fv.options[:with]&.inspect&.sub('\\A', "^")&.sub('\\Z', "$")&.sub('\\z', "$"),
                  without: fv.options[:without]&.inspect&.sub('\\A', "^")&.sub('\\Z', "$")&.sub('\\z', "$"),
                  message: @b.send(:get_error_message, field_name, fv.options[:message]),
                }
              end

              f[:min], f[:max] = validators.select { |v| v.kind == :length }
                .map { |fv| [fv.options[:minimum] || fv.options[:is], fv.options[:maximum] || fv.options[:is]] }
                .first if validators.any? { |v| v.kind == :length }

              f[:min], f[:max], f[:step] = validators.select { |v| v.kind == :numericality }
                .map do |fv|
                in_step = f[:additional_options][:step]
                step = fv.options[:only_integer] ? (in_step || 1).to_i : in_step || "any"
                [
                  fv.options[:greater_than_or_equal_to] || fv.options[:equal_to] || fv.options[:greater_than].try(:+, step),
                  fv.options[:less_than_or_equal_to] || fv.options[:equal_to] || fv.options[:less_than].try(:-, step),
                  step,
                ]
              end
                .first if validators.any? { |v| v.kind == :numericality }

              out[:fields][field_name] = f
            end

            join_nested = -> (nested, form_name = :base, nesteds = []) {
              nested.each { join_nested.call(_1) } if nested.is_a?(Array)
              nested.each { join_nested.call(_1, _2) } if nested.is_a?(Hash)
              if self.class.reflect_on_association(nested)
                model = self.send(nested)
                _nesteds = nesteds
                form_name = case form_name
                  when Symbol then form_name
                  when Array
                    _nesteds = form_name
                    :base
                  when Hash
                    _nesteds = form_name[:nesteds] || []
                    (form_name[:form_name] || form_name[:validation_context] || :base).to_sym
                  else form_name.to_sym
                end
                out[:fields][:"#{nested}_attributes"] = model.form_format(
                  form_name,
                  nesteds: _nesteds,
                  model_name: "#{model_name}[#{nested}_attributes]",
                  **options.dig(:options_for, :"#{nested}_attributes").to_h
                )
              end
            }

            join_nested.call(nesteds)

            out
          end
        end

        return unless mod < ActiveModel::Model

        mod.class_eval do
          def valid?(context = nil)
            context.nil? ? super(:create) : super
          end
        end
      end

      ##
      # @return [Hash{Symbol => UnovaForm::Classes::Form}]
      # noinspection RubyUnnecessaryReturnValue (BECAUSE ||= IS CONSIDERED AS ASSIGMENT.)
      def forms
        @forms ||= {}
        @forms
      end

      ##
      # Will generate forms data and validators on model class with provided #form on its block
      # @yield [void] will get all forms into it
      # @return [void]
      def def_forms
        unless forms.empty?
          return
        end

        yield
        if !forms.has_key?(:create) && forms.has_key?(:base)
          forms[:base].contexts.push :create
          forms[:create] = forms[:base]
        end
        if !forms.has_key?(:update) && forms.has_key?(:base)
          forms[:base].contexts.push :update
          forms[:update] = forms[:base]
        end
        deep_freeze(forms)

        # @type [UnovaForm::Classes::Form] form
        forms.values.uniq.each do |form|
          # @type [Symbol] method
          # @type [UnovaForm::Classes::Field] field
          form.fields.each do |method, field|
            is_confirmation = method.to_s.ends_with?("_confirmation")
            final_validators = field.all_validators.deep_dup
            final_validators[:presence] = true if field.required && field.required_if_persisted && !is_confirmation
            final_validators[:allow_nil] = !field.required || !field.required_if_persisted
            final_validators[:on] = form.contexts

            # If format validation is an array, then adds all validations manually
            if final_validators[:format].is_a?(Array)
              # @type [Hash] fv
              final_validators[:format].each { |fv| validates method, format: fv.merge(allow_blank: true), on: final_validators[:on] }
              final_validators.delete(:format)
            elsif final_validators[:format].is_a?(Hash)
              final_validators[:format] = final_validators[:format].merge(allow_blank: true)
            end
            if final_validators[:timeliness].present?
              begin
                const_get(:TimelinessValidator).present?
              rescue
                require "validates_timeliness"
                ValidatesTimeliness.setup { |config| }
              end
            end

            validates method, **final_validators unless final_validators.except(:on, :allow_nil).empty?
            validates_presence_of method, if: -> { !persisted? }, on: final_validators[:on] if field.required && !field.required_if_persisted && !is_confirmation
            validates_presence_of method, if: -> { eval(method.to_s.gsub(/_confirmation$/, "")).present? }, on: final_validators[:on] if is_confirmation
            validates_confirmation_of method, if: -> { eval(method.to_s).present? }, on: final_validators[:on] if field.has_confirmation
          end
        end
      end

      ##
      # Used to declare form in #def_forms with given context for the builder and validation, #field or #delete_field
      # will be used in its block to add or delete fields into the form
      #
      # @param validation_context [Symbol] the main validation context for form
      # @param include_contexts [Array<Symbol>, NilClass] all context that the form will be added in
      # @param inherits_from [Symbol, NilClass] used to clone other form from context that will be used as base, all future #field declared on this form will override inherited ones if they have same method name and #delete_field will delete inherited fields
      # @param inherited_fields [Array<Symbol>, NilClass] used to select which fields will be inherited from base form
      # @yield [void] will get all fields into it
      # @return [void]
      def form(validation_context = :base, include_contexts: nil, inherits_from: nil, inherited_fields: nil)
        @current_form_context = validation_context
        if inherits_from.present?
          if inherited_fields.present?
            forms[@current_form_context] ||= UnovaForm::Classes::Form.new({}, [])
            inherited_fields&.each do |inherited_field|
              forms[@current_form_context].fields.merge!(forms[inherits_from].fields.select { |k, _| k == inherited_field })
            end
          else
            forms[@current_form_context] = forms[inherits_from].deep_dup
          end
        end
        forms[@current_form_context] ||= UnovaForm::Classes::Form.new({}, [])
        forms[@current_form_context].contexts.delete(inherits_from) if inherits_from.present?
        ([validation_context] + (include_contexts || [])).each { |ctx| forms[@current_form_context].contexts << ctx }
        yield if block_given?
        if include_contexts.is_a?(Array)
          include_contexts&.each { |ctx| forms[ctx] = forms[@current_form_context] }
        end
        @current_form_context = nil
      end

      ##
      # Used to declare field in #form with given validations or options
      #
      # @param [Symbol] method
      # @param [Class<UnovaForm::FieldTypes::Base>, Symbol, String] field_type field type that will be used to determine type validators and field tag type
      # @param [Hash{Symbol => Object}, NilClass] validators validators hash that will be given to a #validates method
      # @param [TrueClass, FalseClass] use_type_validators will add a <field_name>_confirmation field validation, you must add the field yourself
      # @param [TrueClass, FalseClass] has_confirmation define if field will use validators defined in #type, can be override by elements in #validators
      # @param [TrueClass, FalseClass] required define if field is required, will add required attribute to tag, and a presence validator.
      # @param [TrueClass, FalseClass] required_if_persisted if false, if #required is true, will only add required tag and presence validator if model is not persisted
      # @param [Array<Hash{Symbol => String, FalseClass, TrueClass}>, Proc<Array<Hash{Symbol => String, FalseClass, TrueClass}>>, NilClass] options used to transform field into selector, options must have format: [ { value: String, label: String, disabled: Boolean | nil, selected: Boolean | nil } ] And can be a Proc: -> { [ { value: String, label: String, disabled: Boolean | nil, selected: Boolean | nil } ] }
      # @option options [String] :value value of option tag
      # @option options [String] :label label (shown text) of option tag
      # @option options [TrueClass, FalseClass] :selected if option tag is selected
      # @option options [TrueClass, FalseClass] :disabled if option tag is disabled
      # @param [TrueClass, FalseClass] multiple transform selector into a multiselect
      # @return [void]
      def field(method, field_type, validators: nil, use_type_validators: false, has_confirmation: false, required: true, required_if_persisted: true, options: nil, multiple: false, **additional_options)
        forms[@current_form_context].fields[method] = UnovaForm::Classes::Field.new(
          field_type,
          validators,
          has_confirmation,
          use_type_validators,
          required,
          required_if_persisted,
          options,
          multiple,
          **additional_options
        )
      end

      ##
      # Used to delete field in #form if form has been inherited
      def delete_field(method)
        forms[@current_form_context].fields.delete(method)
      end

      private
        def deep_freeze(o)
          o.instance_of?(Hash) ? o.each { |_, val| deep_freeze(val) } : o.each { |val| deep_freeze(val) } if o.respond_to? :each
          o.instance_variables.each do |var|
            frozen_val = o.instance_variable_get(var)
            deep_freeze(frozen_val) unless frozen_val.frozen?
            o.instance_variable_set(var, frozen_val) unless o.frozen?
          end
          o.freeze unless o.frozen? # Freezing of an element.
        end

        def deep_frozen?(o)
          flag = true
          flag = o.instance_of?(Hash) ? o.all? { |_, v| deep_frozen?(v) } : o.all? { |v| deep_frozen?(v) } if o.respond_to? :each
          flag = o.frozen? if flag
          flag = o.instance_variables.all? { |var| deep_frozen?(o.instance_variable_get(var)) } if flag
          flag
        end
    end
  end
end
