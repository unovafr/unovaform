# UNOVA FORM
## Introduction
this library was born because writing forms, especially when they are pretty big, became fastidious,
our solution was to make forms declared into the models.

The gem provide default assets for the forms, that are extendable if you want using\
`rails g unova_foprm:asset js`\
`rails g unova_foprm:asset css`\
the gem will autodetect if you are usinf tailwindcss or not, if you are using css, scss, or sass, for stylesheets and
if you are using ts or js for javascript, and will generate the correct file for you.\
You can customize all theme using cli interactive creation.


Forms are declared as follow:
```ruby
class Model
  extend UnovaForm::Concerns::HasForm # You must EXTEND, not include it

  # main form definition block, must be called once as the definition stored in the model will be frozen
  def_forms do
    # with no context provided, it will declare the form on :base context
    # all validations will be applied to the form's context
    form do
      field(
        # the attribute name
        # Note:
        #   - if name ends with _confirmation, it will be required if the original field is filled
        #   - select fields must have :select or :check_select types
        #   - check_select will create radio buttons if multiple is false, and checkboxes otherwise
        #   - select multiple will need the "multiselect" stimulus controller provided by rails g unova_form:asset js
        #     this behavior can be overriden by overriding the UnovaForm::Helpers::InputHelper#select_field method
        #   - if the field is a password, a button will be provided to show/hide the password, using the "password-field" 
        #     stimulus controller
        #   - if the field is a file field, a preview will be shown if the file is an image, video, or audio, 
        #     using the "file-field" stimulus controller
        #   - if the field is a number field with controls, the field will have up and down buttons to increment/decrement 
        #     the value, using the "number-field" stimulus controller
        :name,
        # the type of the field, could be :string. any UnovaForm::FieldTypes::Base subclass will be accepted
        UnovaForm::FieldTypes::String,
        # the validators, this hash will be passed to rails's validates method, with on: <form_context> option
        # like validates :method, **<validators>, on: <form_context>
        # Note:
        #   - if length validator is provided, it will fill min and max attributes on html field by default
        #   - if presence validator is provided, it will fill required attribute on html field and label by default
        #   - if format validator is provided, it will fill pattern attribute on html field by default
        #      - pattern conversion might fail, and dont work on frontend, please make an issue if you need it
        #   - format validator can be an array of multiple formats
        #   - if numericality validator is provided, it will fill min and max attribute on html field by default
        #   - for dates, the gem provides validates_timeliness gem, so you can use it
        # default: {}
        validators: {
          length: {maximum: 255}
        },
        # if the field has a :<method>_confirmation attribute that needs to be set, usefull for password confirmation
        # shortcut for validators: {confirmation: { if: ->{<method>.present?} }}
        # default: false
        has_confirmation: false,
        # if the field is a password, positive_integer, etc..., UnovaForm::FieldTypes::<type> will contains
        # default validators, if you want to disable them, set this to false, true otherwise
        # default: false
        use_type_validators: false,
        # if the field is required, shortcut for validators: {presence: true}
        # default: true
        required: true,
        # if the field is required only if model is persisted, if false, it is equivalent to the shortcut for 
        # validators: {presence: { if: ->{!persisted?} }}, if true, it will simply follow required
        # default: true
        required_if_persisted: true,
        # if the field can have a datalist, it will be filled using the provided proc/array
        # if the field is a select or check_select, options will be filled using the provided proc/array
        # otherwise, it will be ignored
        # output format must be an array of hashes with :value, :label, :selected, and :disabled keys like:
        #   [{value: 'value', label: 'label', selected: true, disabled: false}]
        # by default, the selected value will be the placeholder if value is nil, or the value itself, if no selected is provided
        # if you provide a proc, it will be called with the current value, and the model as facultative arguments
        # default: nil
        options: [],
        # if the field is a checkSelect
        
        
      )
      
    end
    # at the end of execution of the block, if no :update or :create context was provided,
    # it will be set to :base, if provided, it will be set to the last context provided, 
    # with validators duplicated to their respective context
  end 
end
```