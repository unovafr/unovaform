# frozen_string_literal: true

module UnovaForm
  # =Global builder for UnovaForm
  # will build fields based on model's declared forms
  #
  # Inspections, ignore them:
  # noinspection ThisExpressionReferencesGlobalObjectJS will be on oninvalid, this will be the input
  # noinspection RubyTooManyMethodsInspection wants to keep all methods here because all are utils and +class+ is simpler like this for me
  class Builder < ActionView::Helpers::FormBuilder
    # ```javascript
    # let s = this;
    # if(s.dataset.patternMessages && s.value)
    #   for (let [r, m] of Object.entries(JSON.parse(s.dataset.patternMessages))) {
    #     if (!new RegExp(
    #       // convert all HTML entities to characters
    #       Object.assign(document.createElement("textarea"), {innerHTML: r}).value
    #     ).test(s.value)) {
    #       s.setCustomValidity(m);
    #       break;
    #     } else  {
    #       s.setCustomValidity('');
    #     }
    #   }
    # ```
    # JS in variable is minified version of above code.
    AUTOVALIDATE_JS_STRING = <<~JS.gsub(/\n\s*/, "").strip.freeze
      let s=this;
      if(s.dataset.patternMessages && s.value){
        const m = Object.entries(JSON.parse(s.dataset.patternMessages)).find(([r]) => !new RegExp(Object.assign(document.createElement('textarea'),{innerHTML:r}).value).test(s.value));
        if(m){s.setCustomValidity(m[1])}else{s.setCustomValidity('')}
      } else {s.setCustomValidity('')}
    JS
    delegate :content_tag, :tag, :safe_join, :rails_direct_uploads_url, :capture, :concat, to: :@template

    # @return [Module<UnovaForm::Helpers::InputHelper>]
    def self.input_helper
      @input_helper ||= UnovaForm::Helpers::InputHelper
    end

    # =This method allows to override default input helper
    # Usage:
    #   UnovaForm::Builder.input_helper = MyCustomInputHelper
    #
    # @param [Module<UnovaForm::Helpers::InputHelper>] val
    # @return [Module<UnovaForm::Helpers::InputHelper>]
    def self.input_helper=(val)
      input_helper.instance_methods.each { |m| undef_method m }
      include val
      @input_helper = val
    end

    include self.input_helper

    # @return [Hash{Symbol => UnovaForm::Classes::Form}]
    def forms
      object.class.forms
    end

    # =Add all fields to dom based on stored form with given context
    # For example:
    #   Having a model +User+ with:
    #     def_forms do
    #       form :create do
    #         field :email, UnovaForm::FieldTypes::Email, use_type_validators: true, required: true
    #         field :password, UnovaForm::FieldTypes::Password, required: true
    #       end
    #       form :update do
    #         field :lastname, UnovaForm::FieldTypes::String
    #         field :firstname, UnovaForm::FieldTypes::String
    #         field :email, UnovaForm::FieldTypes::Email, use_type_validators: true
    #         field :phone_number, UnovaForm::FieldTypes::Tel, use_type_validators: true
    #         field :password, UnovaForm::FieldTypes::Password
    #       end
    #     end
    #
    #   You can generate create form with:
    #     <%= uform_for @user do |form| %>
    #       <%= form.fields :create %>
    #     <% end %>
    #
    #   You can generate update form with:
    #     <%= uform_for @user do |form| %>
    #       <%= form.fields :update %>
    #     <% end %>
    #
    #   You also can customize your structure update form with:
    #     <%= uform_for @user do |form| %>
    #       <div class="custom">
    #         <%= form.fields :update, only: :email %>
    #       </div>
    #       <%= form.fields :update, omit: [:email, :password] %>
    #       <div class="custom">
    #         <%= form.fields :update, only: :password %>
    #       </div>
    #     <% end %>
    #
    #   You can pass data that will be sent to helpers:
    #     <%= uform_for @user do |form| %>
    #       <%= form.fields :update, container_class: "bg-red-500" %>
    #     <% end %>
    #
    #   You can pass field-specific data that will be sent to helpers:
    #     <%= uform_for @user do |form| %>
    #       <%= form.fields :update, options_for: { email: { container_class: "bg-red-500" } } %>
    #     <% end %>
    #
    #   You can disable labels:
    #     <%= uform_for @user do |form| %>
    #       <%= form.fields :update, no_labels: true %>
    #     <% end %>
    #
    # @param [Symbol] validation_context form's context
    # @param [Array<Symbol>, Symbol] omit fields blacklist
    # @param [Array<Symbol>, Symbol] only fields whitelist
    # @param [FalseClass, TrueClass] no_labels disable labels on all fields
    # @param [Hash{Symbol => Hash{Symbol => Object}}] options_for field-specific options ex: { email: { container_class: "bg-res-500" } }
    # @param [Hash] options other options that will be sent to fields and helpers that builds fields see UnovaForm::Helpers::InputHelper
    # @return [String]
    def fields(validation_context = :base, omit: nil, only: nil, no_labels: false, options_for: {}, **options)
      check_form(validation_context)

      # allow field if not in omit and if only is nil or only include field
      safe_join(
        forms[validation_context].fields.filter_map do |method, _|
          # exclude field if in omit (if omit is present) or if only is present and not include field
          # if omit include field, and only include field, omit will be prioritized
          next if (omit.present? && filter_has_method?(omit, method)) || !(only.nil? || filter_has_method?(only, method))

          field method, validation_context:, no_label: no_labels, **options, **options_for[method].to_h
        end
      )
    end

    # =Add one field to dom based on stored form with given context
    #
    # Similar to #fields used like this:
    #   <%= uform_for @user do |form| %>
    #     <%= form.fields :update, only: :email %> # => will only generate email field, on update form context
    #   <% end %>
    # using #field method:
    #   <%= uform_for @user do |form| %>
    #     <%= form.field :email, :update %> # => will only generate email field, on update form context
    #   <% end %>
    # @see #field for more informations
    #
    #
    # @param [Symbol] method
    # @param [Symbol] validation_context form's context
    # @param [Hash] options other options that will be sent to helpers that builds fields and/or override builder attributes
    # @option options [String, NilClass] :label
    # @return [ActionView::Helpers::TagHelper::TagBuilder, ActiveSupport::SafeBuffer]
    def field(
      method,
      validation_context: :base,
      **options
    )
      check_form(validation_context)

      @field = nil if @current_method != method
      # @type [Symbol] current_method
      @current_method = method

      type = current_tag_type

      attrs = {
        id: current_tag_id,
        name: current_tag_name,
        value: type == :time ? current_value&.strftime("%I:%M:%S") : current_value,
        type:,
        error: current_errors,
        required: current_required?,
        options: current_options,
        placeholder: current_human_name_for(:placeholders),
        **parse_additional_options(current_field.additional_options).merge(
          parse_additional_options(options.except(:no_label, :label))
        ) do |k, v1, v2|
          case v1
            when Hash
              v1.merge(v2) do |k1, v11, v22|
                case v11
                  when Hash then v11.merge(v22)
                  when String, Array then array_attr([v11, v22])
                  else v22
                end
              end
            when String, Array then array_attr([v1, v2])
            else v2
          end
        end,
      }

      label = nil
      label = current_human_name_for(override_with: options[:label]).html_safe unless options[:no_label]

      render_field_using_attrs(label, attrs)
    end

    # Generate sub-form using UnovaForm::Builder, using rails built-in fields_for
    # @see #fields_for
    # @see UnovaForm::Builder
    # Example:
    #   parent_form.ufields_for @model.attribute_model do |form|
    #     form.kind_of?(UnovaForm::Builder)  => false (if not the default form builder)
    #   end
    #
    #   parent_form.ufields_for @model.attribute_model do |form|
    #     form.kind_of?(UnovaForm::Builder)  => true
    #   end
    #
    # @param [Unknown] rna record or name or array (model or attribute)
    # @param [Array] args
    # @yield [form] Build your form using UnovaForm::Builder
    # @yieldparam [UnovaForm::Builder] form Builder with UnovaForm::Builder. you still can use base rails features
    # @return [ActionView::Helpers::TagHelper::TagBuilder, ActiveSupport::SafeBuffer]
    def ufields_for(rna, *args, &block)
      # @type [UnovaForm::Builder] form
      fields_for(rna, *args, &block)
    end

    private

      # @param [String | NilClass] label
      # @param [Hash] attrs
      def render_field_using_attrs(label, attrs)
        return select_field label, multiple: multiple?, **attrs if attrs[:options].is_a?(Array) && %i[select checkboxes].include?(attrs[:type])

        options = attrs.delete(:options)

        case attrs[:type]
          when :file
            return file_field label,
                              value: current_file_value,
                              value_url: current_file_value_url,
                              accept: current_accepted_files&.join(","),
                              value_type: current_file_type,
                              multiple: multiple?,
                              **attrs.except(:value, :placeholder, :type)
          when :checkbox
            return boolean_field label, checked: current_value == true, **attrs.except(:value)
          else
            nil
        end

        # import minimum / maximum value from length validator or numericality validator
        min, max = convert_len_num_validators_to_minmax(
          current_field.all_validators[:length],
          current_field.all_validators[:numericality]
        )

        pattern, pattern_messages = manage_format_validator

        step = current_field.all_validators[:numericality].try(:[], :only_integer) ? 1 : "any" if current_field.all_validators[:numericality].present?

        input_field label, min:, max:, step:, options:,
          **({ pattern:, data: { pattern_messages: pattern_messages.html_safe }, oninput: AUTOVALIDATE_JS_STRING } if pattern.present? && pattern_messages.present? && pattern_messages != "{}").to_h,
          **attrs
      end

      # noinspection RailsParamDefResolve false positive because Object is for dynamic type
      def convert_len_validator_to_minmax(len)
        [
          len[:minimum] || (len[:in] || len[:within]).try(:first) || len[:is],
          len[:maximum] || (len[:in] || len[:within]).try(:last) || len[:is]
        ]
      end

      # noinspection RailsParamDefResolve false positive because Object is for dynamic type
      def convert_num_validator_to_minmax(num, step)
        [
          num[:greater_than_or_equal_to] || num[:equal_to] || num[:in].try(:first) || num[:greater_than].try(:+, step),
          num[:less_than_or_equal_to] || num[:equal_to] || num[:in].try(:last) || num[:less_than].try(:-, step)
        ]
      end

      # noinspection RailsParamDefResolve
      def convert_len_num_validators_to_minmax(len, num, step = 1)
        if len.is_a?(Hash)
          convert_len_validator_to_minmax len
        elsif num.is_a?(Hash)
          convert_num_validator_to_minmax num, step
        end
      end

      # check if filter variable contains method
      #
      # @param [Array<Symbol>, Symbol, NilClass] filter
      # @return [TrueClass, FalseClass]
      def filter_has_method?(filter, method) = filter.present? && (filter.try(:include?, method) || filter == method)

      def get_error_message(method, message)
        return object.errors.generate_message method, message if message.is_a?(Symbol)

        message.to_s
      end

      def convert_regex_to_js(regex)
        safe_join([
                    regex.inspect.sub('\\A', "^").sub('\\Z', "$").sub('\\z', "$").sub(%r{^/}, "").sub(%r{/[a-z]*$}, "").gsub(/\(\?#.+\)/, "").gsub(/\(\?-\w+:/, "(")
                  ])
      end

      def validator_to_html_pattern(validator, pattern_messages)
        { with: "?=", without: "?!" }.map do |key, lookahead|
          next if validator[key].blank?

          reg = convert_regex_to_js(validator[key])
          pattern_messages[reg] = get_error_message(@current_method, validator[:message])
          "(#{lookahead}#{'.*' unless reg.starts_with?('^')}#{reg})"
        end.join
      end

      def manage_format_validator
        format_validators = current_field.all_validators[:format]

        # @type [Hash{String => String}] pattern_messages
        pattern_messages = {}

        # @type [String, NilClass] pattern
        # import and concat patterns from format validators
        pattern = case format_validators
          when Array then "#{format_validators.map { |v| validator_to_html_pattern(v, pattern_messages) }.join}.*"
          when Hash then "#{validator_to_html_pattern(format_validators, pattern_messages)}.*"
          else return ["", "{}"]
        end

        [pattern.gsub("\"", "\\\""), pattern_messages.to_json]
      end

      # @return [UnovaForm::Classes::Field]
      # noinspection RubyMismatchedReturnType (RETURN TYPE WILL BE CORRECT)
      def current_field
        @field ||= forms[@current_validation_context].fields[@current_method]
        raise Exception.new("model #{object.class} dont have field :#{@current_method} on form :#{@current_validation_context}.") if @field.nil? || !@field

        @field
      end

      # @param [UnovaForm::Classes::Field, NilClass] val
      # @return [UnovaForm::Classes::Field, NilClass]
      def current_field=(val)
        @field = val
      end

      # @return [Hash{Symbol => Object}]
      def model_attributes
        attrs = Hash.new
        object.instance_variables.each do |var|
          str = var.to_s.gsub(/^@/, "")
          if object.respond_to? "#{str}="
            attrs[str.to_sym] = instance_variable_get var
          end
        end
        attrs
      end

      # @return [Object, NilClass]
      def current_value
        return object.try(@current_method) if object.respond_to?(@current_method)
        return object[@current_method] if object.respond_to?(:[])

        model_attributes[@current_method]
      end

      # @return [String]
      def current_tag_name
        "#{object_name}[#{@current_method}]"
      end

      # @return [String]
      def current_tag_id
        "#{object_name.tr('[', '_').delete(']')}_#{@current_method}-#{(0...20).map { ('a'..'z').to_a[rand(26)] }.join}"
      end

      # @return [Symbol]
      def current_tag_type
        current_field.type::INPUT_TYPE
      end

      # @return [ActionView::Helpers::TagHelper::TagBuilder, ActiveSupport::SafeBuffer]
      def current_errors
        return unless current_errors?

        safe_join(object.errors.delete(@current_method), tag.br)
      end

      # @return [TrueClass, FalseClass]
      def current_errors?
        object.errors&.key?(@current_method) || false
      end

      # @return [TrueClass, FalseClass]
      # noinspection RailsParamDefResolve false positive because Object is for dynamic type
      def current_required?
        persisted = object.try(:persisted?) || false
        (current_field.required && (!persisted || current_field.required_if_persisted)) || false
      end

      # @return [Array<Hash{Symbol => String, TrueClass, FalseClass}>, NilClass]
      # noinspection RailsParamDefResolve false positive because Object is for dynamic type
      def current_options
        # noinspection RubyMismatchedArgumentType False positive
        if [Proc, Array].include?(current_field.options.class)
          return case current_field.options.try(:arity) # arity is the number of arguments, if arity is nil, it's a array
            when 0 then current_field.options.try(:call)
            when 1 then current_field.options.try(:call, current_value)
            when 2 then current_field.options.try(:call, current_value, object)
            when nil then current_field.options.try(:map) do |h|
              h.deep_dup.symbolize_keys.tap { |nh| nh[:selected] = nh[:value] == current_value }
            end
            else nil
          end
        end
        nil
      end

      def parse_additional_options(additional_options)
        groups = %w[container subcontainer input label icon placeholder]
        group_options={}
        res = additional_options.map do |k, v|
          group = groups.find { |g| k.to_s.start_with?("#{g}_") || (k.to_s == g && v.is_a?(Hash)) }
          if group
            group_options[:"#{group}_options"] ||= {}
            group_options[:"#{group}_options"][k.to_s.gsub("#{group}_", "").to_sym] = v if v.is_a?(String)
            group_options[:"#{group}_options"].merge!(v) if v.is_a?(Hash)
            nil
          else
            [k, v]
          end
        end.compact.to_h

        group_options.symbolize_keys!
        group_options.each { |_, v| v.symbolize_keys! }

        res.merge(group_options)
      end

      # @return [FalseClass, TrueClass]
      def multiple?
        current_field.multiple || false
      end

      # @return [ActiveStorage::Blob]
      def current_file_value
        object.try(@current_method)
      end

      # @return [String]
      def current_file_value_url
        current_file_value&.url || ""
      end

      def file_type_from_method_name
        case @current_method.to_s
          when /video/, /mp4/, /avi/, /mov/, /mkv/, /webm/, /wmv/, /flv/, /ogv/, /gifv/ then :video
          when /avatar/, /image/, /img/, /picture/, /photo/, /jpg/, /png/, /bitmap/, /gif/, /svg/, /webp/ then :img
          when /sound/, /audio/, /mp3/, /music/, /song/, /flac/, /wav/, /ogg/, /oga/, /opus/, /m4a/, /aac/, /wma/, /alac/, /aiff/ then :audio
          else
            :other
        end
      end

      # @return [Symbol]
      def current_file_type
        type = current_accepted_files || object.try(@current_method).try(:content_type) || object.try(@current_method).try(:blob).try(:content_type)
        type = type[0].to_s if type.is_a?(Array)
        case type
          when /^image/ then :img
          when /^video/ then :video
          when /^audio/ then :audio
          else file_type_from_method_name
        end
      end

      # @return [Array<String>, NilClass]
      # noinspection RubyMismatchedReturnType
      def current_accepted_files
        current_field.all_validators.try(:[], :content_type).try(:[], :in)
      end

      # @param [Symbol] element
      # @param [String | NilClass] override_with
      # @param [Hash] options
      # @return [String]
      def current_human_name_for(element = :attributes, override_with: nil, **options)
        return override_with if override_with.present?

        defaults = object.class.lookup_ancestors.flat_map do |klass|
          [
            :"#{object.class.i18n_scope}.#{element}.#{klass.model_name.i18n_key}.#{@current_method}",
            # for ones that dont want keys like module/model, but path module.model
            (:"#{object.class.i18n_scope}.#{element}.#{klass.model_name.i18n_key.to_s.tr('/', '.')}.#{@current_method}" if klass.model_name.i18n_key.to_s.include?('/')),
            # for ones that have all model translations in one file:
            # active_record:
            #   <model_name>:
            #     attributes:
            #       **attributes**
            #     placeholders:
            #       **placeholders**
            :"#{object.class.i18n_scope}.#{klass.model_name.i18n_key}.#{element}.#{@current_method}",
          ].reject(&:nil?)
        end

        defaults << :"#{element}.#{@current_method}"
        defaults << options.delete(:default) if options[:default]
        # avoid to show missing translation error on production
        defaults << @current_method.to_s.humanize if Rails.env.production?

        options.reverse_merge! count: 1, default: defaults
        I18n.t(defaults.shift, **options).html_safe
      end

      # @param [Symbol] validation_context
      # @return [void]
      def check_form(validation_context)
        # @type [Symbol] current_validation_context
        @current_validation_context = validation_context

        raise "model #{object.class} must extend UnovaForm::Concern::HasForm" unless object.class.respond_to?(:forms)

        raise "model #{object.class} dont have form for :#{validation_context} context." unless forms.key?(validation_context)
      end
  end
end
