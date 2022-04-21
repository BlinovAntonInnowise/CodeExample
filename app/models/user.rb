class User < ApplicationRecord
  include Activities, RoleManagement, Nameable
  Anonymous = OpenStruct.new(:full_name => nil, :initials => nil)

  # Include default devise modules. Others available are:
  # :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable,
         :validatable, :confirmable, :lockable, :timeoutable

  normalize_attributes :email

  belongs_to :group

  has_many :contacts, :foreign_key => :assignee_id, :dependent => :nullify
  has_many :accounts, :through => :contacts
  has_many :account_lists, -> { by_title }
  has_many :opportunities, :dependent => :nullify
  has_many :expected_turnovers, :class_name => "Campaign::ExpectedTurnover"

  scope :active, -> { where(deactivated_at: nil) }
  scope :deactivated, -> { where.not(deactivated_at: nil) }

  def self.search(term, options = {})
    where("CONCAT(first_name, last_name) ILIKE ?", "%#{term}%").
      by_reverse_full_name
  end

  def accounts_count
    accounts.count
  end

  def contacts_count
    contacts.count
  end

  def open_opportunities_count
    opportunities.open.count
  end

  def closed_opportunities_count
    opportunities.closed.count
  end

  def update_and_confirm(attributes)
    update(attributes) && confirm
  end

  def own_and_groups_user_ids
    group_id.present? ? group.user_ids : [id]
  end

  def in_same_group_as?(other)
    group.present? && group == other.try(:group)
  end

  def expected_turnovers_for(campaigns)
    expected_turnovers.where(campaign_id: campaigns.map(&:id))
  end

  def update_without_reconfirmation(attributes)
    skip_reconfirmation!
    update(attributes)
  end

  def active_for_authentication?
    super && deactivated_at.blank?
  end

  def activate
    update_column(:deactivated_at, nil) if deactivated?
  end

  def deactivate(reassign_data_to: nil)
    unless deactivated?
      update_column(:deactivated_at, Time.current)

      return unless reassign_data_to.present?
      opportunities.open.update_all(:user_id => reassign_data_to.id)
      contacts.update_all(:assignee_id => reassign_data_to.id)
      todos.update_all(:user_id => reassign_data_to.id)
    end
  end

  def deactivated?
    deactivated_at.present?
  end

  def inactive_message
    !deactivated? ? super : :deactivated
  end

private

  def password_required?
    persisted? && (password.present? || password_confirmation.present?)
  end

end
