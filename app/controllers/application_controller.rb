class ApplicationController < ActionController::Base
  include Breadcrumbs, Expose

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.

  rescue_from CanCan::AccessDenied do |exception|
    render :template => 'application/forbidden', :layout => 'application', :status => :forbidden
  end

  after_action :flash_to_headers

  load_and_authorize_resource :prepend => true, :if => :resource_controller?
  prepend_before_action :authenticate_user!

  def default_url_options(options={})
    { :protocol => "https" }
  end

private

  def set_flash_message(status, timing = :after_redirect, options = {})
    flash_key = status == :success ? :notice : :alert
    flash_hash = timing == :now ? flash.now : flash

    full_controller_name = self.class.name.sub(/Controller$/, '').underscore.gsub('/', '.')
    key = :"flash.#{full_controller_name}.#{action_name}.#{status}"
    defaults = [:"flash.#{controller_name}.#{action_name}.#{status}", :"flash.#{action_name}.#{status}", :"flash.#{status}"]

    options.reverse_merge!(:resource_name => I18n.t(resource_name, :scope => 'activerecord.models'), :default => defaults)

    flash_hash[flash_key] = I18n.t(key, options).html_safe
  end

  def flash_to_headers
    return unless request.xhr?

    flash.keys.each do |key|
      response.headers['X-Message'] = flash[key]
      response.headers['X-Message-Type'] = key
    end

    flash.discard
  end

  def resource_name
    controller_name.singularize
  end

  def resource
    send(resource_name)
  end

  def resource_controller?
    !devise_controller?
  end

  def decorated_current_user
    @decorated_current_user ||= current_user.try(:decorate)
  end
  helper_method :decorated_current_user

end
