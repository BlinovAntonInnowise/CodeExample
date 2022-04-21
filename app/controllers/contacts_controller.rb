class ContactsController < ApplicationController
  skip_load_resource :only => :index
  skip_load_and_authorize_resource only: [:all, :without_account, :search, :export, :delete_multiple]

  expose(:contacts)
  expose(:contact)
  expose(:per_page, decorate: false) { 100 }

  expose(:account)
  decorates_assigned :account
  decorates_assigned :contact
  decorates_assigned :contacts

  respond_to :html, :xlsx, :only => :index

  def index
    params[:letter] ||= 'A'
    @contacts = current_user.contacts.by_reverse_full_name
    @scope = @contacts
    @contacts = @contacts.for_letter(params[:letter]) if params[:letter].present?
  end

  def all
    params[:letter] ||= 'A'
    @contacts = Contact.accessible_by(current_ability).by_reverse_full_name
    @scope = @contacts
    @contacts = @contacts.for_letter(params[:letter]) if params[:letter].present?

    authorize!(:read, Contact)

    render :index
  end

  def without_account
    @contacts = Contact.without_account.by_reverse_full_name
    @scope = @contacts
    @contacts = @contacts.for_letter(params[:letter]) if params[:letter].present?

    authorize!(:read, Contact)

    render :index
  end

  def search
    authorize!(:read, Account)

    @contacts = if params[:q].present?
      query = ThinkingSphinx::Query.wildcard(params[:q] || '')
      options = { order: :reverse_full_name }

      Contact.search(query, options)
    else
      Kaminari.paginate_array([])
    end.page(params[:page]).per(per_page)
  end

  def export
    authorize!(:read, Contact)

    contacts = ContactsDecorator.decorate(Contact.accessible_by(current_ability).where(id: params[:contact_ids]))
    filename = "#{Time.current.to_s(:db)} NDA"
    filename << case params[:type]
    when 'mail'       then ' NDA'
    when 'newsletter' then ' NDA'
    end.to_s

    xlsx = contacts.to_xlsx(type: params[:type])
    send_data xlsx.to_stream.string, filename: "#{filename}.xlsx", type: :xlsx
  end

  def show
    @account = Account.find(params[:account_id]) if params[:account_id].present?
  end

  def new
    build_associations
  end

  def create
    contact.model.assignee ||= current_user

    if contact.model.save
      set_flash_message(:success)
      redirect_to contact
    else
      build_associations

      set_flash_message(:failure, :now)
      render :edit
    end
  end

  def edit
    build_associations
  end

  def update
    if contact.model.update(contact_params)
      set_flash_message(:success)
      redirect_to contact
    else
      build_associations
      set_flash_message(:failure, :now)
      render :edit
    end
  end

  def destroy
    contact.model.destroy
    set_flash_message(:success)
    redirect_to contacts_url(:letter => contact.model.letter)
  end

  def delete_multiple
    authorize!(:destroy, Contact)

    contacts = Contact.accessible_by(current_ability).where(id: params[:contact_ids])

    contacts.destroy_all
    set_flash_message(:success)

    redirect_back fallback_location: root_path
  end

private

  def contact_params
    params[:contact] ||= {}

    permitted_attributes = [
      :assignee_id,
      :first_name, :last_name, :gender, :prefix, :suffix,
      :notes,
      { :jobs_attributes => [:id, :account_id, :title, :start_date, :end_date, :mail_recipient, :_destroy] }
    ]

    Contact.phone_types.each do |type|
      permitted_attributes << { :"#{type}_attributes" => [:id, :number] }
    end

    Contact.email_address_types.each do |type|
      permitted_attributes << { :"#{type}_attributes" => [:id, :email, :newsletter_recipient] }
    end

    params[:contact].permit(*permitted_attributes)
  end

  def build_associations
    contact.model.jobs.build unless contact.jobs.any?

    (Contact.phone_types + Contact.email_address_types).each do |type|
      contact.model.public_send(:"build_#{type}") unless contact.model.public_send(type).present?
    end
  end

end
