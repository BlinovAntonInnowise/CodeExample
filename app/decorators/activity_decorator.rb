class ActivityDecorator < ApplicationDecorator
  decorates :activity
  decorates_association :user
  decorates_association :account
  decorates_association :contact
  decorates_association :opportunity
  decorates_association :documents

  delegate :title, :completed?, :calendar_week
  delegate :initials_label, :to => :user, :prefix => true, :allow_nil => true
  delegate :full_name, :to => :contact, :prefix => true, :allow_nil => true
  delegate :title, :to => :opportunity, :prefix => true, :allow_nil => true

  def linked_title(*args)
    if model.completed?
      options = args.extract_options!
      options.deep_merge!(:data => { :toggle => "modal", :target => "#activity-details" })
      super(*(args << options))
    else
      super(h.todo_path(model), *args)
    end
  end

  def status_text
    case
    when model.completed? then 'NDA'
    when model.overdue?   then 'NDA'
    else                       'NDA'
    end
  end

  def status_label
    classes = %w[label]

    classes << case
               when model.completed? then 'label-success'
               when model.overdue?   then 'label-danger'
               else                       'label-warning'
               end

    h.content_tag(:div, status_text, :class => classes.join(' ').html_safe)
  end

  def status_label_with_date
    classes = %w[todo--status label]

    case
    when model.completed?
      classes << 'label-success'
      date_text = "NDA: #{completed_at}"
    when model.overdue?
      classes << 'label-danger'
      date_text = "NDA: #{due_at}"
    else
      classes << 'label-warning'
      date_text = "NDA: #{due_at}"
    end

    text = status_text + h.content_tag(:div, date_text, :class => 'todo--status-date')
    h.content_tag(:div, text.html_safe, :class => classes.join(' ').html_safe)
  end

  def linked_trackable
    h.link_to(trackable.label_for_link, trackable)
  end

  def trackable_params
    { :trackable_type => model.trackable.class.name.underscore, :trackable_id => model.trackable.id }
  end

  def completed_at
    time(model.completed_at)
  end

  def completed_on
    date(model.completed_at) if model.completed?
  end

  def has_due_date?
    model.due_at.present?
  end

  def due_on(options = {})
    date(model.due_on, options)
  end

  def due_at(options = {})
    time(model.due_at, options)
  end

  def completed_at
    h.l(model.completed_at) if model.completed_at.present?
  end

  def type
    h.t(model.type, :scope => 'simple_form.options.activity.type')
  end

  def type_icon
    icon = case model.type
    when 'email'   then 'NDA'
    when 'call'    then 'NDA'
    when 'meeting' then 'NDA'
    end

    h.content_tag(:span, nil, :class => "glyphicon glyphicon-#{icon}")
  end

  def icon_and_type
    type_icon + '&nbsp;'.html_safe + type
  end

  def user_name
    user.try(:full_name) || 'NDA'
  end

  def account_name
    account.present? ? account.name : 'NDA'
  end

  def linked_account_name(*)
    model.account.present? ? super : 'NDA'
  end

  def notes
    return 'NDA' unless model.notes.present?

    markdown(model.notes)
  end

  def created_on
    date(model.created_at)
  end

  def created_at
    time(model.created_at)
  end
end
