# frozen_string_literal: true

module UnovaForm
  module Helpers
    module InputHelper
      extend ActionView::Helpers::TagHelper
      extend ActionView::Context

      PASSWORD_FIELD_DEFAULT_ICON = '<svg focuseable="false" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 570 512" width="16"><path fill="currentColor" d="M288 80c-65.2 0-118.8 29.6-159.9 67.7C89.6 183.5 63 226 49.4 256c13.6 30 40.2 72.5 78.6 108.3C169.2 402.4 222.8 432 288 432s118.8-29.6 159.9-67.7C486.4 328.5 513 286 526.6 256c-13.6-30-40.2-72.5-78.6-108.3C406.8 109.6 353.2 80 288 80zM95.4 112.6C142.5 68.8 207.2 32 288 32s145.5 36.8 192.6 80.6c46.8 43.5 78.1 95.4 93 131.1c3.3 7.9 3.3 16.7 0 24.6c-14.9 35.7-46.2 87.7-93 131.1C433.5 443.2 368.8 480 288 480s-145.5-36.8-192.6-80.6C48.6 356 17.3 304 2.5 268.3c-3.3-7.9-3.3-16.7 0-24.6C17.3 208 48.6 156 95.4 112.6zM288 336c44.2 0 80-35.8 80-80s-35.8-80-80-80c-.7 0-1.3 0-2 0c1.3 5.1 2 10.5 2 16c0 35.3-28.7 64-64 64c-5.5 0-10.9-.7-16-2c0 .7 0 1.3 0 2c0 44.2 35.8 80 80 80zm0-208a128 128 0 1 1 0 256 128 128 0 1 1 0-256z"></path></svg>'.html_safe.freeze
      SEARCH_FIELD_DEFAULT_ICON = '<svg focuseable="false" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="16"><path fill="currentColor" d="M416 208c0 45.9-14.9 88.3-40 122.7L502.6 457.4c12.5 12.5 12.5 32.8 0 45.3s-32.8 12.5-45.3 0L330.7 376c-34.4 25.2-76.8 40-122.7 40C93.1 416 0 322.9 0 208S93.1 0 208 0S416 93.1 416 208zM208 352a144 144 0 1 0 0-288 144 144 0 1 0 0 288z"></path></svg>'.html_safe.freeze
      FILE_FIELD_DEFAULT_ICON = '<svg focuseable="false" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="16"><path fill="currentColor" d="M19 9h-4V3H9v6H5l7 8zM4 19h16v2H4z"></path></svg>'.html_safe.freeze

      # These are bound stimulus controller by default to input fields of given types
      #
      # @return [Hash{Symbol => String}]
      def controllers_for_types = @controllers_for_types ||= {
        password: "password-field",
        multiselect: "multiselect",
        number: "number-field",
        file: "file-field",
      }

      # Used to generate random id for fields to be able to link label to input if no id is given
      #
      # @return [String] random id string
      def random_id = (0...50).map { ("a".."z").to_a[rand(26)] }.join

      # Used to transform strings like "Hello   wOrld" into "hello world" that is more suitable for html attributes
      #
      # @param [String, NilClass] string string to be beautified
      # @return [String] beautified string
      def beautify_string_attr(string) = string.gsub(/\s+/, " ").downcase

      # Used to transform array of strings like ["Hello   wOrld", "  foo"] into "hello world foo"
      # from array for usefulness lower-cased and beautified to be more suitable for html attributes
      def array_attr(array) = array
                                .filter_map { |s| beautify_string_attr(s) if s.present? }.join(" ")

      # Used to remove stimulus controller for input field type
      #
      # @param [Symbol] type
      # @return [String, NilClass]
      def remove_controller_for_type(type) = controllers_for_types.delete(type)

      # Used to add stimulus controller for input field type
      #
      # @param [Symbol] type
      # @param [String] controller
      # @return [String]
      def add_controller_for_type(type, controller) = controllers_for_types[type] = controller

      # Used to get stimulus controller for input field type
      #
      # @param [Symbol] type
      # @return [String, NilClass]
      def controller_for_type(type) = controllers_for_types[type]

      def data_controller_of(type, current_controller)
        if type.nil?
          return nil unless current_controller.present?
          return beautify_string_attr(current_controller.to_s)
        end
        array_attr [controller_for_type(type.to_sym), current_controller.to_s]
      end

      # @param [String, NilClass] label
      # @param [Symbol, String, NilClass] id
      # @param [Symbol, String, NilClass] type
      # @param [ActionView::Helpers::TagHelper::TagBuilder , ActiveSupport::SafeBuffer , String, NilClass] error
      # @param [String, NilClass] container_class
      # @param [String, NilClass] label_class
      # @param [String, NilClass] subcontainer_class
      # @param [Symbol, String, NilClass] controller
      # @param [TrueClass, FalseClass, NilClass] omit_subcontainer
      # @param [Array<Hash{Symbol => String, FalseClass, TrueClass}>] options
      # @param [TrueClass, FalseClass, NilClass] required
      # @option options [String] :value value of option tag
      # @option options [String] :label label (shown text) of option tag
      # @option options [TrueClass, FalseClass] :selected if option tag is selected
      # @option options [TrueClass, FalseClass] :disabled if option tag is disabled
      # @return [ActionView::Helpers::TagHelper::TagBuilder, ActiveSupport::SafeBuffer]
      def field_container(label, id: nil, type: nil, error: nil, container_class: nil, label_class: nil, subcontainer_class: nil, controller: nil, omit_subcontainer: false, options: nil, required: false)
        # @type [String, NilClass] data_controller

        tag.div(
            class: array_attr(["field", container_class]),
            data: {
              controller: data_controller_of(type, controller),
              options: (options if type == :multiselect)
            }
          ) do
          els = []
          els << tag.div(error, class: "error") if error
          els << (omit_subcontainer ? yield : tag.div(
            yield,
            class: array_attr(["field-container#{"-full" if type == :textarea}", subcontainer_class]),
          ))
          els << tag.label(label, for: id, class: label_class, required:) if label.present?

          safe_join(els)
        end
      end

      # @param [String, NilClass] label
      # @param [Symbol, String, NilClass] id
      # @param [Symbol, String, NilClass] type
      # @param [Symbol, String, NilClass] name
      # @param [ActionView::Helpers::TagHelper::TagBuilder , ActiveSupport::SafeBuffer, String, NilClass] error
      # @param [Object, NilClass] value
      # @param [TrueClass, FalseClass, NilClass] required
      # @param [String, NilClass] placeholder
      # @param [ActionView::Helpers::TagHelper::TagBuilder , ActiveSupport::SafeBuffer, String, NilClass] icon
      # @param [TrueClass, FalseClass, NilClass] is_icon_left
      # @param [String, NilClass] container_class
      # @param [String, NilClass] input_class
      # @param [String, NilClass] label_class
      # @param [String, NilClass] icon_class
      # @param [String] rows
      # @param [Symbol, String, NilClass] controller
      # @param [TrueClass, FalseClass] with_controls
      # @param [TrueClass, FalseClass] controls_on_input
      # @param [Numeric, NilClass] min
      # @param [Numeric, NilClass] max
      # @param [Numeric, NilClass] step
      # @param [String, NilClass] pattern
      # @return [ActionView::Helpers::TagHelper::TagBuilder, ActiveSupport::SafeBuffer]
      def input_field(label, id: nil, type: :text, name: nil, error: nil, value: nil, required: nil, disabled: nil, placeholder: nil, icon: nil, is_icon_left: nil, container_class: nil, input_class: nil, label_class: nil, icon_class: nil, rows: "3", controller: nil, with_controls: false, controls_on_input: false, min: nil, max: nil, step: nil, pattern: nil, options: nil, **_options)
        id ||= random_id

        case type
        when :password
          icon ||= PASSWORD_FIELD_DEFAULT_ICON
          is_icon_left ||= false
        when :search
          icon ||= SEARCH_FIELD_DEFAULT_ICON
          is_icon_left ||= false
        else
          is_icon_left ||= false
        end

        # fields like number, have a step attribute.
        is_length = [:date, :month,  :week, :time, :'datetime-local', :number, :range,].exclude?(type&.to_sym)
        minmax = is_length ? { min:, max:, step: } : { min:, max: }

        els = []
        els << tag.button("-", type: :button,
          class: array_attr(["field-number-minus", ("on-input" if controls_on_input)]),
          data: { action: "click->number-field#sub" }
        ) if with_controls && type == :number

        value = case type
          when :textarea then nil
          when :'datetime-local' then value&.strftime("%Y-%m-%dT%H:%M")
          else value
        end
        
        els << content_tag(
          type == :textarea ? :textarea : :input,
          (value if type == :textarea),
          type:,
          value:,
          placeholder:,
          required:,
          id:,
          disabled:,
          list: options.present? ? id + "_list" : nil,
          rows: (rows if type == :textarea),
          name: name || id,
          class: array_attr([
                              input_class,
                              ("with-controls#{"-on-input" if controls_on_input}" if with_controls),
                              ("with-icon#{"-left" if is_icon_left}" if icon.present?)
                            ]),
          title: (placeholder || name || id if label.nil?),
          pattern: pattern&.gsub("\"", "\\\"")&.gsub("\\", "\\\\")&.html_safe,
          step:,
          **minmax,
          **_options
        )

        els << tag.button("+", type: :button,
          class: array_attr(["field-number-plus", ("on-input" if controls_on_input)]),
          data: { action: "click->number-field#add" }
        ) if with_controls && type == :number

        els << tag.div(icon,
                       class: array_attr(["icon", icon_class, ("left" if is_icon_left)]),
                       data: ({ action: "click->password-field#toggle" } if type == :password)
        ) if icon.present? && !with_controls

        if options.present?
          els << content_tag(:datalist,
            safe_join(options.map { |d| tag.option(d[:label], value: d[:value], disabled: d[:disabled]) }),
            id: id + "_list",
          )
        end

        field_container(label, id:, type:, error:, container_class:, label_class:, required:, controller:) { safe_join(els) }
      end

      # @param [String, NilClass] label
      # @param [Symbol, String, NilClass] id
      # @param [Symbol, String, NilClass] type
      # @param [Symbol, String, NilClass] name
      # @param [ActionView::Helpers::TagHelper::TagBuilder , ActiveSupport::SafeBuffer , String, NilClass] error
      # @param [Object, NilClass] value
      # @param [TrueClass, FalseClass, NilClass] required
      # @param [String, NilClass] placeholder
      # @param [Array<Hash{Symbol => String, FalseClass, TrueClass}>] options
      # @param [ActionView::Helpers::TagHelper::TagBuilder , ActiveSupport::SafeBuffer, String, NilClass] icon
      # @param [TrueClass, FalseClass, NilClass] is_icon_left
      # @param [String, NilClass] container_class
      # @param [String, NilClass] input_class
      # @param [String, NilClass] label_class
      # @param [String, NilClass] icon_class
      # @param [Symbol, String, NilClass] controller
      # @param [FalseClass, TrueClass] multiple
      # @option options [String] :value value of option tag
      # @option options [String] :label label (shown text) of option tag
      # @option options [TrueClass, FalseClass] :selected if option tag is selected
      # @option options [TrueClass, FalseClass] :disabled if option tag is disabled
      # @return [ActionView::Helpers::TagHelper::TagBuilder, ActiveSupport::SafeBuffer]
      def select_field(label, id: nil, type: :select, name: nil, error: nil, value: nil, required: nil, disabled: nil, placeholder: "select", options: [], icon: nil, is_icon_left: nil, container_class: nil, input_class: nil, label_class: nil, icon_class: nil, controller: nil, multiple: false, **_options)
        id ||= random_id
        options ||= []
        options.unshift({ value: "", label: placeholder, disabled: required || multiple, selected: value.blank? }) if placeholder.present? && placeholder != ""

        unless [:select, :checkboxes].include?(type&.to_sym)
          raise "Select fields must have :select or :checkboxes types respectively provided by UnovaForm::FormTypes::Select UnovaForm::FormTypes::CheckSelect"
        end

        name += "[]" if multiple && name.present?

        select_el = case type
        when :select
          tag.select(
            safe_join(options.map { |o|
              o[:selected] ||= multiple ? value&.include?(o[:value]) : o[:value] == value
              tag.option(o[:label], value: o[:value], selected: o[:selected], disabled: o[:disabled])
            }),
            id:,
            name: name || id,
            required:,
            class: array_attr([
                                input_class,
                                ("with-icon#{"-left" if is_icon_left}" if icon.present?)
                              ]),
            title: (placeholder || name || id if label.nil?),
            multiple:,
            disabled:,
            **_options
          )
        when :checkboxes
          safe_join(options.reject { |o| o[:disabled] }.map do |o|
            cid = random_id
            tag.div(safe_join([
              tag.input(
                nil,
                type: multiple ? :checkbox : :radio,
                value: o[:value],
                id: cid,
                name: name || id,
                class: input_class,
                checked: o[:selected] || (multiple ? value&.include?(o[:value]) : o[:value] == value),
                title: (placeholder || name || cid if o[:label].empty?),
                disabled: o[:disabled] || disabled,
                **_options
              ),
              tag.label(
                o[:label],
                for: cid
              )
            ]), class: "field-checkboxes-item")
          end)
        else
          nil
        end

        field_container(label, id:,
          type: multiple && type == :select ? :multiselect : :text,
          omit_subcontainer: multiple && type == :select,
          error:, container_class:, label_class:, controller:, required:) do
          safe_join([ select_el,
                      (tag.div(icon, class: array_attr(["icon", icon_class, ("left" if is_icon_left)])) if type == :select)
                    ])
        end
      end

      # @param [String, NilClass] label
      # @param [Symbol, String, NilClass] id
      # @param [Symbol, String, NilClass] type
      # @param [Symbol, String, NilClass] name
      # @param [ActionView::Helpers::TagHelper::TagBuilder , ActiveSupport::SafeBuffer , String, NilClass] error
      # @param [Object, NilClass] value
      # @param [TrueClass, FalseClass, NilClass] required
      # @param [String, NilClass] placeholder
      # @param [String, NilClass] container_class
      # @param [String, NilClass] input_class
      # @param [String, NilClass] label_class
      # @param [Symbol, String, NilClass] controller
      # @param [TrueClass, FalseClass, NilClass] checked
      # @return [ActionView::Helpers::TagHelper::TagBuilder, ActiveSupport::SafeBuffer]
      def boolean_field(label, id: nil, type: :checkbox, name: nil, error: nil, value: "true", required: nil, disabled: nil, placeholder: "accept", container_class: nil, input_class: nil, label_class: nil, controller: nil, checked: nil, **options)
        id ||= random_id

        unless [:checkbox].include?(type&.to_sym)
          raise "Boolean fields must have :checkbox types respectively provided by UnovaForm::FormTypes::Boolean"
        end

        field_container(label, id: nil, type:, error:, container_class:, label_class:, controller:) do
          tag.div(
            safe_join([
              tag.input(
                nil,
                type:,
                value:,
                id:,
                name: name || id,
                class: input_class.to_s,
                checked:,
                title: (placeholder || name || id if label.nil?),
                required:,
                disabled:,
                **options
              ),
              (tag.label(placeholder, for: id) if placeholder.present?)
            ]),
            class: "field-checkboxes-item"
          )
        end
      end

      PREVIEWABLE_CONTENT_TYPES = [
        *UnovaForm::FieldTypes::ImageFile::VALIDATORS[:content_type][:in],
        *UnovaForm::FieldTypes::VideoFile::VALIDATORS[:content_type][:in],
        *UnovaForm::FieldTypes::SoundFile::VALIDATORS[:content_type][:in],
      ].freeze

      # @param [String, NilClass] label
      # @param [Symbol, String, NilClass] id
      # @param [Symbol] value_type
      # @param [Symbol, String, NilClass] name
      # @param [ActionView::Helpers::TagHelper::TagBuilder , ActiveSupport::SafeBuffer , String, NilClass] error
      # @param [Object, Array<Object>, NilClass] value
      # @param [ActiveStorage::Blob, Array<ActiveStorage::Blob>, NilClass] value_url
      # @param [TrueClass, FalseClass, NilClass] multiple
      # @param [TrueClass, FalseClass, NilClass] required
      # @param [ActionView::Helpers::TagHelper::TagBuilder , ActiveSupport::SafeBuffer, String, NilClass] icon
      # @param [ActionView::Helpers::TagHelper::TagBuilder , ActiveSupport::SafeBuffer, String, NilClass] remove_icon
      # @param [String, NilClass] accept
      # @param [String, NilClass] container_class
      # @param [String, NilClass] input_class
      # @param [String, NilClass] label_class
      # @param [Symbol, String, NilClass] controller
      # @param [Hash{Symbol => String}] data
      # @return [ActionView::Helpers::TagHelper::TagBuilder, ActiveSupport::SafeBuffer]
      # noinspection RailsI18nInspection
      def file_field(label, id: "", value_type: :other, name: nil, error: nil, value: nil, value_url: nil, multiple: nil, required: nil, disabled: nil, icon: nil, remove_icon: nil, accept: nil, container_class: "large", input_class: nil, label_class: nil, controller: nil, data: {}, **options)
        id ||= random_id

        icon ||= FILE_FIELD_DEFAULT_ICON
        remove_icon ||= "X".html_safe.freeze

        previewable = accept.present? && accept&.split(",")&.any? { |t| PREVIEWABLE_CONTENT_TYPES.include?(t) } || value_type != :other

        name += "[]" if multiple && name.present?

        field_container(nil, id:, type: :file, error:, container_class:, label_class:, controller:, omit_subcontainer: true) do
          safe_join([
            content_tag(
              :input,
              "",
              type: :file,
              required: value&.present? ? false : required,
              id:,
              accept:,
              name: name || id,
              class: array_attr([input_class, ("filled" if value&.present?)]),
              aria_hidden: true,
              multiple:,
              data: {
                action: "change->file-field#change",
                'direct-upload-url': (options[:direct_upload_url] || rails_direct_uploads_url if options[:direct_upload_url] != "none"),
                'form-type': :other
              }.merge(data){ |key, old, new| key == "action" ? "#{old} #{new}" : new },
              disabled:,
              **options
            ),
            (
              content_tag :label, for: id, class: label_class.to_s do
                content_tag(:span, tag.span(label) + tag.span(I18n.t(:edit)), class: "label") +
                  (
                    content_tag :div, class: "preview-container#{" multiple" if multiple}#{" no-preview" unless previewable}" do

                      content_tag(:div, icon + content_tag(:span, I18n.t(:select_file), class: "filename mt-1"), class: "preview-placeholder") +
                        (
                          if multiple && value
                            safe_join(value&.map_with_index do |v, i|
                              (!previewable ? tag.div(v.filename, class: "preview") : content_tag(value_type, "", src: value_url[i], class: "preview", controls: value_type != :img, alt: "file_input_preview", size: "400x200"))
                            end)
                          else
                            (!previewable ? tag.div(value&.filename, class: "preview") : content_tag(value_type, "", src: value_url, class: "preview", controls: value_type != :img, alt: "file_input_preview", size: "400x200"))
                          end
                        ) +
                        content_tag(:button, remove_icon, data: { action: "click->file-field#reset" }, title: I18n.t(:reset), type: :button)
                    end
                  )
              end
            )
          ])
        end
      end

      module_function :input_field, :boolean_field, :file_field, :select_field, :field_container, :controllers_for_types, :controller_for_type, :add_controller_for_type, :remove_controller_for_type, :data_controller_of, :random_id, :beautify_string_attr, :array_attr
    end
  end
end
