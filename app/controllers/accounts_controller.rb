class AccountsController < ApplicationController
  skip_load_and_authorize_resource only: [:index, :all, :without_contacts, :search, :export, :export_contacts, :delete_multiple]

  expose(:accounts)
  expose(:account)
  expose(:per_page, decorate: false) { 100 }

  expose(:region)
  expose(:topic)
  expose(:user)
  decorates_assigned :accounts
  decorates_assigned :account
  decorates_assigned :region
  decorates_assigned :topic
  decorates_assigned :user

  before_action only: [:index, :all, :without_contacts] do
    @region = Region.find(params[:region_id]) if params[:region_id].present? && params[:region_id] != 'none'
    @topic = Topic.find(params[:topic_id]) if params[:topic_id].present? && params[:topic_id] != 'none'
    @user = User.find(params[:user_id]) if params[:user_id].present?
  end

  respond_to :html, :xlsx, :only => [:index, :all, :without_contacts]

  def index
    @accounts = filter_accounts(Account.with_contacts_assigned_to(current_user))

    authorize!(:read, Account)
  end

  def all
    @accounts = filter_accounts(Account.all)

    authorize!(:read, Account)

    render :index
  end

  def without_contacts
    @accounts = filter_accounts(Account.without_contacts)

    authorize!(:read, Account)

    render :index
  end

  def search
    authorize!(:read, Account)

    @accounts = if %i[q region_ids topic_ids user_ids].any? { |field| params[field].present? }
      query = ThinkingSphinx::Query.wildcard(params[:q] || '')
      options = { order: :name }

      %i[region_ids topic_ids user_ids].each do |field|
        if params[field].present?
          if params[field] == 'none'
            klass = field.to_s.split('_').first.classify.constantize
            (options[:without] ||= {})[field] = klass.pluck(:id)
          else
            (options[:with] ||= {})[field] = params[field].to_i
          end
        end
      end

      Account.search(query, options)
    else
      Kaminari.paginate_array([])
    end.page(params[:page]).per(per_page)

    @accounts = AccountsDecorator.decorate(@accounts)

    @facets = Account.facets(query)

    @region_facets = Hash[Region.where(id: @facets[:region_ids].keys).by_full_name.map { |region| [region.decorate, @facets[:region_ids][region.id]] }]
    @topic_facets = Hash[Topic.where(id: @facets[:topic_ids].keys).by_full_name.map { |topic| [topic.decorate, @facets[:topic_ids][topic.id]] }]
    @user_facets = Hash[User.where(id: @facets[:user_ids].keys).by_reverse_full_name.map { |user| [user.decorate, @facets[:user_ids][user.id]] }]
  end

  def export
    authorize!(:read, Account)

    accounts = AccountDecorator.decorate_collection(Account.where(id: params[:account_ids]))
    filename = "#{params[:list_title] || Time.current.to_s(:db)} NDA.xlsx"

    xlsx = accounts.to_xlsx
    send_data xlsx.to_stream.string, filename: filename, type: :xlsx
  end

  def export_contacts
    authorize!(:read, Account)

    accounts = Account.where(id: params[:account_ids])
    contacts = ContactsDecorator.decorate(Contact.joins(:jobs).where(jobs: { account_id: accounts.pluck(:id) }).accessible_by(current_ability))
    filename = "#{params[:list_title] || Time.current.to_s(:db)} NDA"
    filename << case params[:type]
    when 'mail'       then ' NDA'
    when 'newsletter' then ' NDA'
    else                   ''
    end.to_s

    xlsx = contacts.to_xlsx(type: params[:type], accounts: accounts)
    send_data xlsx.to_stream.string, filename: "#{filename}.xlsx", type: :xlsx
  end

  def new
    build_associations
  end

  def create
    if account.model.save
      set_flash_message(:success)
      redirect_to account
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
    begin
      if account.model.update(account_params)
        set_flash_message(:success)
        redirect_to account
      else
        build_associations

        set_flash_message(:failure, :now)
        render :edit
      end
    rescue => e
      render text: "error: #{e.record.inspect}"
    end
  end

  def destroy
    account.model.destroy
    set_flash_message(:success)
    redirect_to [:accounts]
  end

  def delete_multiple
    authorize!(:destroy, Account)

    accounts = Account.accessible_by(current_ability).where(id: params[:account_ids])

    accounts.destroy_all
    set_flash_message(:success)

    redirect_to [:all, :accounts]
  end

private

  def filter_accounts(accounts)
    accounts = accounts.by_name.includes(:address, :regions, :topics)

    if %w[region_id topic_id user_id].any? { |key| params[key].present? }
      if params[:region_id].present?
        accounts = accounts.for_region(params[:region_id] == 'none' ? nil : params[:region_id])
      end

      if params[:topic_id].present?
        accounts = accounts.for_topic(params[:topic_id] == 'none' ? nil : params[:topic_id])
      end

      accounts = accounts.with_contacts_assigned_to(params[:user_id]) if params[:user_id].present?

      accounts
    else
      accounts.count <= 100 ? accounts : []
    end
  end

  def account_params
    params.fetch(:account, {}).permit(
      :name, :alternative_names_list,
      :parent_id,
      :notes,
      account_list_ids: [],
      region_ids: [],
      topic_ids: [],
      address_attributes: [:id, :line_1, :line_2, :zipcode, :city, :country_code],
      landline_attributes: [:id, :number],
      fax_attributes: [:id, :number],
      work_email_address_attributes: [:id, :email],
      website_attributes: [:id, :url],
      account_connections_attributes: [:id, :connection_id, :name, :start_date, :end_date, :_destroy]
    )
  end

  def build_associations
    account.model.account_connections.build unless account.model.account_connections.any?
    account.model.build_address  unless account.model.address.present?

    (account.model.phone_types + account.model.email_address_types + account.model.website_types).each do |type|
      account.model.public_send(:"build_#{type}") unless account.model.public_send(type).present?
    end
  end

end
