module PriceCalculation
  extend ActiveSupport::Concern

  DISCOUNT_MODES = %w[discount_mode_percentage discount_mode_price]
  AGENCY_DISCOUNT_MODES = %w[agency_discount_mode_percentage agency_discount_mode_price]

  included do
    enum :discount_mode => DISCOUNT_MODES.map(&:to_sym), :agency_discount_mode => AGENCY_DISCOUNT_MODES.map(&:to_sym)

    has_many :items, :class_name => 'OpportunityItem'
    accepts_nested_attributes_for :items, :reject_if => ->(attributes) { attributes[:product_price_id].blank? || attributes[:quantity].blank? }, :allow_destroy => true

    validates :discount_mode, :presence => true, :inclusion => { :in => DISCOUNT_MODES, :allow_blank => true }
    validates :agency_discount_mode, :presence => true, :inclusion => { :in => AGENCY_DISCOUNT_MODES, :allow_blank => true }

    with_options :numericality => { :greater_than_or_equal_to => 0, :less_than_or_equal_to => 100, :allow_blank => true } do |v|
      v.validates :discount_percentage, :presence => { :if => :discount_mode_percentage? }
      v.validates :agency_discount_percentage, :presence => { :if => :agency_discount_mode_percentage? }
    end

    with_options :numericality => { :greater_than_or_equal_to => 0, :allow_blank => true } do |v|
      v.validates :discounted_price, :presence => { :if => :discount_mode_price? }
      v.validates :final_price, :presence => { :if => :agency_discount_mode_price? }
    end

    after_initialize :set_discount_defaults
  end

  def product_prices
    campaign.try(:product_prices) || []
  end

  def list_price
    items.to_a.sum(&:total)
  end

  def discount_percentage
    discount_mode_percentage? ? super : calculate_discount_percentage
  end

  def discounted_price
    discount_mode_price? ? super : calculate_discounted_price
  end

  def agency_discount_percentage
    agency_discount_mode_percentage? ? super : calculate_agency_discount_percentage
  end

  def final_price
    agency_discount_mode_price? ? super : calculate_final_price
  end

private

  def calculate_discount_percentage
    (list_price - discounted_price) / list_price * 100 rescue 0
  end

  def calculate_discounted_price
    list_price * (100 - (discount_percentage || 0)) / 100
  end

  def calculate_agency_discount_percentage
    (discounted_price - final_price) / discounted_price * 100 rescue 0
  end

  def calculate_final_price
    discounted_price * (100 - (agency_discount_percentage || 0)) / 100
  end

  def set_discount_defaults
    self.discount_mode ||= DISCOUNT_MODES.first
    self.agency_discount_mode ||= AGENCY_DISCOUNT_MODES.first
  end

end
