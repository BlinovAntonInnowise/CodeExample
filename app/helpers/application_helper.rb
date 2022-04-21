module ApplicationHelper
  def modal(template, options = {})
    options = { :partial => template, :layout => 'layouts/modal', :locals => options }
    content_for(:modals, render(options))
  end

  def can_manage_any?(*klasses)
    klasses.any? { |klass| can?(:manage, klass) }
  end

  def can_read_any?(*klasses)
    klasses.any? { |klass| can?(:read, klass) }
  end

  def link_to_add_fields(name, f, association)
    new_object = f.object.send(association).klass.new
    id = new_object.object_id
    fields = f.fields_for(association, new_object, horizontal_form_options) do |builder|
      render("group_orders/form_fields", f: builder, order: new_object, first: false)
    end
    link_to(name, '#', class: 'add_fields btn btn-success', data: {id: id, fields: fields.gsub("\n", "")})
  end

  def month_select_options
    {
      :order => [:month, :year],
      :start_year => Date.current.year + 1,
      :end_year => 1950,
      :include_blank => true
    }
  end

  def truncate_email(email, length = 60)
    address, host = email.split('@')
    return email if address.length <= length

    truncate(address, length: length) { |g| "@#{host}" }
  end
end
