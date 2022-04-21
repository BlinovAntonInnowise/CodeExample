module EmailAddresses
  extend ActiveSupport::Concern
  include DestroyIfBlank

  included do
    options = { as: :emailable }
    options.merge!(dependent: :destroy) unless paranoid?
    has_many :email_addresses, options
  end

  module ClassMethods
    attr_reader :email_address_types

    def has_email_addresses(*types)
      @email_address_types = types

      types.each do |type|
        has_one type, -> { where(:type => type) }, :class_name => 'EmailAddress', :as => :emailable
        accepts_nested_attributes_for type, :allow_destroy => true, :update_only => true, :reject_if => :reject_email?
      end
    end
  end

  def email_address_types
    self.class.email_address_types
  end

private

  def reject_email?(attributes)
    mark_for_destruction_if_blank(attributes, :email)

    attributes[:id].blank? && attributes[:email].blank?
  end

end
