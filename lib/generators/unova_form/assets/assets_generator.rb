# frozen_string_literal: true

require "rails/generators/named_base"

class UnovaForm::AssetsGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__ || __FILE__.split("/")[0...-1].join("/"))

  def generate_asset
    raise "Invalid asset type: #{asset_type}, must be one of #{allowed_asset_types.join(', ')}" unless allowed_asset_types.include?(asset_type)
    stylesheets if asset_type.in?(%w[css scss styles stylesheets])
    javascripts if asset_type.in?(%w[js javascripts])
  end

  private
    def allowed_asset_types = %w[css scss styles stylesheets js javascripts]

    def stylesheets
      # ask for schema
      schema = nil
      while schema.nil?
        schema = ask("What stylesheet schema do you want to use? (#{allowed_stylesheet_schemas.join(', ')}) default: #{allowed_stylesheet_schemas.first}")
        schema = schema.downcase.strip
        schema = allowed_stylesheet_schemas.first if schema.blank?
        schema = nil unless allowed_stylesheet_schemas.include?(schema)
      end

      # ask for framework
      framework = nil
      while framework.nil?
        framework = ask("What framework do you want to use? (#{allowed_stylesheet_frameworks.join(', ')}) default: #{allowed_stylesheet_frameworks.first}")
        framework = framework.downcase.strip
        framework = allowed_stylesheet_frameworks.first if framework.blank?
        framework = nil unless allowed_stylesheet_frameworks.include?(framework)
      end

      # ask for destination
      destination = existing_stylesheet_dest
      while destination.nil?
        destination = ask("Cannot find a valid destination, (tested: #{default_stylesheet_dests.join(', ')}), please enter a valid destination for your stylesheet files:")
        destination = nil unless File.directory?(destination)
      end

      @theme = {}
      case framework
        when "tailwind"
          @theme[:label_color] = "color-gray-700"
          @theme[:label_font_size] = "text-sm"
          @theme[:label_font_weight] = "font-normal"
          @theme[:label_font_family] = "font-sans"
          @theme[:label_margin_bottom] = "mb-1"
          @theme[:input_border_color] = "border-gray-300"
          @theme[:input_border_width] = "border"
          @theme[:input_border_radius] = "rounded-md"
          @theme[:input_padding] = "px-3 py-2"
          @theme[:input_color] = "text-gray-900"
          @theme[:input_font_size] = "text-base"
          @theme[:input_font_weight] = "font-normal"
          @theme[:input_font_family] = "font-sans"
          @theme[:input_background_color] = "bg-white"
          @theme[:input_placeholder_color] = "placeholder-gray-500"
          @theme[:input_focus_border_color] = "focus:border-blue-500"
          @theme[:error_color] = "text-red-500"
          @theme[:error_font_size] = "text-sm"
          @theme[:error_font_weight] = "font-normal"
          @theme[:error_font_family] = "font-sans"
          @theme[:error_margin_top] = "mt-1"
          @theme[:error_margin_bottom] = "mb-1"
        else
          @theme[:label_color] = "#000000"
          @theme[:label_font_size] = "1rem"
          @theme[:label_font_weight] = "400"
          @theme[:label_font_family] = "sans-serif"
          @theme[:label_margin_bottom] = "0.25rem"
          @theme[:input_border_color] = "#000000"
          @theme[:input_border_width] = "1px"
          @theme[:input_border_radius] = "0.25rem"
          @theme[:input_padding] = "0.375rem 0.75rem"
          @theme[:input_color] = "#000000"
          @theme[:input_font_size] = "1rem"
          @theme[:input_font_weight] = "400"
          @theme[:input_font_family] = "sans-serif"
          @theme[:input_background_color] = "#ffffff"
          @theme[:input_placeholder_color] = "#6c757d"
          @theme[:input_focus_border_color] = "#000000"
          @theme[:error_color] = "#dc3545"
          @theme[:error_font_size] = "0.875rem"
          @theme[:error_font_weight] = "400"
          @theme[:error_font_family] = "sans-serif"
          @theme[:error_margin_top] = "0.25rem"
          @theme[:error_margin_bottom] = "0.25rem"
      end

      # say @theme and ask if want to edit
      say "Here is your theme:}"
      @theme.each { |k, v| say "   #{k}: #{v}" }
      if yes?("Do you want to edit it? (y/n)")
        # ask if step by step is wanted or not
        if yes?("Do you want to edit it step by step? (y/n), if you answer no, you will be asked if you want to edit individual values.")
          @theme.each do |k, v|
            ans = ask("#{k}: (#{v})")
            @theme[k] = ans if ans.present?
          end
        else
          # ask if want to edit individual values
          if yes?("Do you want to edit any @theme value?")
            el_editing = "notBlank"
            while el_editing.present?
              # ask for element to edit
              el_editing = ask("What element do you want to edit? (#{@theme.keys.join(', ')}) leave blank to stop editing")
              continue if el_editing.blank?
              el_editing = el_editing.downcase.strip
              continue unless @theme.key?(el_editing)
              @theme[el_editing] = ask("#{el_editing}: (#{@theme[el_editing]})") if @theme.key?(el_editing)
            end
          end
        end
      end

      say "Generating stylesheet with schema: #{schema}, framework: #{framework} on destination: #{destination}"

      case framework
      when "tailwind"
        template "tailwind.#{schema}.erb", "#{destination}/unova_form.#{schema}"
      else
        template "vanilla.#{schema}.erb", "#{destination}/unova_form.#{schema}"
      end

      say "Stylesheet generated, trying to add it to your application css file"

      application_css = "#{destination}/application.#{schema}"
      until File.exist?(application_css)
        application_css = ask("Cannot find #{application_css}, please enter the relative path to your application css file:")
      end

      case application_css.split(".").last
        when "scss"
          prepend_to_file application_css, "@import 'unova_form';\n"
        when "sass"
          prepend_to_file application_css, "@import 'unova_form'\n"
        else
          prepend_to_file application_css, "@import 'unova_form.css';\n"
      end
    end

    def javascripts

    end

    def asset_type = name

    def default_stylesheet_dests = %w[app/assets/stylesheets app/frontend/stylesheets]
    def existing_stylesheet_dest
      default_stylesheet_dests.find { |d| File.directory?(d) }
    end
    def allowed_stylesheet_schemas = %w[css scss sass]
    def allowed_stylesheet_frameworks = %w[vanilla tailwind]
end