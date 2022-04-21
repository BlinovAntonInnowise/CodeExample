module Breadcrumbs
  extend ActiveSupport::Concern

  included do
    before_action :set_crumbs, :if => :set_crumbs?
  end

private

  def set_crumbs?
    user_signed_in? && !devise_controller?
  end

  def set_crumbs
    add_crumb('NDA', '/')
    return set_groups_order_crumbs if controller_name == 'group_orders'
    set_collection_crumbs
    set_instance_crumbs if action_name.in?(%w[show new create edit update destroy])
  end

  def set_collection_crumbs
    add_crumb(t(:index, :scope => breadcrumbs_i18n_scope), polymorphic_path([controller_name.to_sym]))
  end

  def set_instance_crumbs
    if resource != nil
      if resource.persisted?
        add_crumb(resource.to_crumb, polymorphic_path([resource]))
      else
        add_crumb(t(:new, :scope => breadcrumbs_i18n_scope), polymorphic_path([:new, resource_name.to_sym]))
      end
      add_crumb(t(:edit, :scope => breadcrumbs_i18n_scope), polymorphic_path([:edit, resource])) if action_name.in?(%w[edit update])
    else
      if resource
        add_crumb(resource.to_crumb, polymorphic_path([resource]))
      else
        add_crumb(t(:new, :scope => breadcrumbs_i18n_scope), polymorphic_path([:new, resource_name.to_sym]))
      end
    end

  end

  def set_groups_order_crumbs
    add_crumb "NDA", '/orders'
    add_crumb "NDA"
  end

  def breadcrumbs_i18n_scope
    "breadcrumbs.#{controller_name}"
  end

end
