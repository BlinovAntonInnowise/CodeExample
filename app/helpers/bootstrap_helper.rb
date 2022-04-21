module BootstrapHelper
  def icon(icon_name, options = {})
    (options[:class] ||= '') << " glyphicon glyphicon-#{icon_name}"

    content_tag(:span, nil, options)
  end

  def link_with_icon(label, icon_name, url, options = {})
    text = icon(icon_name)
    text << content_tag(:span, label, class: 'text') if label.present?

    options[:class] ||= ''
    options[:class] << 'link-with-icon'

    link_to(text, url, options)
  end

  def link_button(label, url, size = nil, options = {})
    options[:class] ||= ''
    options[:class] << ' btn'
    options[:class] << ' btn-default' unless options[:class] =~ /btn-(primary|success|info|warning|danger|link)/
    options[:class] << " btn-#{size}" if size.present?

    link_to(label, url, options)
  end

  def link_button_with_icon(label, icon_name, url, size = nil, options = {})
    text = icon(icon_name)
    text << content_tag(:span, label, class: 'text') if label.present?

    link_button(text.html_safe, url, size, options)
  end

  def button_with_icon(label, icon_name, options = {})
    options.reverse_merge!(:type => 'button')

    text = icon(icon_name)
    text << content_tag(:span, label, class: 'text') if label.present?

    content_tag(:button, text.html_safe, options)
  end

  def save_button
    content_tag(:div, :class => 'form-group') do
      button_with_icon('Speichern', :ok, :type => 'submit', :class => 'btn btn-primary')
    end
  end

  def vertical_form_options
    {
      :wrapper_mappings => {
        :boolean => :vertical_boolean
      }
    }
  end

  def horizontal_form_options
    {
      :html => { :class => 'form-horizontal' },
      :wrapper => :horizontal_form,
      :wrapper_mappings => {
        :check_boxes => :horizontal_radio_and_checkboxes,
        :radio_buttons => :horizontal_radio_and_checkboxes,
        :file => :horizontal_file_input,
        :boolean => :horizontal_boolean
      }
    }
  end
end
