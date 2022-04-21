class Account < ApplicationRecord
  acts_as_paranoid

  include Activities, Addresses, EmailAddresses, Phones, Lists, Websites

  has_ancestry
  normalize_attributes :name, :notes

  has_many :region_assignments, class_name: 'AccountRegionAssignment'
  has_many :regions, through: :region_assignments

  has_phones :landline, :fax
  has_email_addresses :work_email_address
  has_websites :website
  has_lists :alternative_names

  has_many :account_list_assignments, dependent: :destroy
  has_many :account_lists, through: :account_list_assignments

  has_many :opportunities

  has_many :jobs, :dependent => :destroy
  has_many :contacts, -> { by_reverse_full_name }, through: :jobs

  has_many :account_connections, :dependent => :destroy
  has_many :inverse_account_connections, :class_name => "AccountConnection", :foreign_key => "connection_id", :dependent => :destroy
  accepts_nested_attributes_for :account_connections, :reject_if => :reject_connection?, :allow_destroy => true

  has_many :topic_assignments, class_name: 'AccountTopicAssignment'
  has_many :topics, through: :topic_assignments

  validates :name, :presence => true # uniqueness?

  validate :parent_not_self, :on => :update

  scope :by_name, -> { order("#{table_name}.name ASC") }
  scope :for_letter, ->(letter) { where("#{table_name}.name ~* ?", "^[#{letter}]") }

  before_save :cache_regions_and_topics
  after_destroy :delete_pending_opportunities

  class << self
    def assignee_account_counts
      sql = <<-sql
        SELECT
          "users"."id" AS user_id,
          COUNT("accounts"".id") AS accounts_count
        FROM users
          LEFT JOIN "contacts" ON "users"."id" = "contacts"."assignee_id"
          LEFT JOIN "jobs" ON "contacts"."id" = "jobs"."contact_id"
          LEFT JOIN "accounts" ON "jobs"."account_id" = "accounts"."id"
        WHERE"contacts"."deleted_at" IS NULL
          AND "jobs"."deleted_at" IS NULL
          AND "accounts"."deleted_at" IS NULL
        GROUP BY "users"."id"
      sql

      ActiveRecord::Base.connection.select_all(sql).inject({}) do |assignee_account_counts, row|
        assignee_account_counts[row['user_id'].to_i] ||= {}
        assignee_account_counts[row['user_id'].to_i] = row['accounts_count'].to_i
        assignee_account_counts
      end
    end

    def assignee_contact_counts
      sql = <<-sql
        SELECT
          "accounts"."id" AS account_id,
          ("users"."first_name" || ', ' || "users"."last_name") AS user_full_name,
          "users"."initials" AS user_initials,
          COUNT("jobs".*) AS contacts_count
        FROM accounts
          LEFT JOIN "jobs" ON "accounts"."id" = "jobs"."account_id"
          LEFT JOIN "contacts" ON "jobs"."contact_id" = "contacts"."id"
          LEFT JOIN "users" ON "contacts"."assignee_id" = "users"."id"
        WHERE "accounts"."deleted_at" IS NULL
          AND "contacts"."deleted_at" IS NULL
          AND "jobs"."deleted_at" IS NULL
        GROUP BY "users"."first_name", "users"."last_name", "users"."initials", "accounts"."id"
      sql

      ActiveRecord::Base.connection.select_all(sql).inject({}) do |assignee_contact_counts, row|
        user = OpenStruct.new(:initials => row['user_initials'], :full_name => row['user_full_name'])

        assignee_contact_counts[row['account_id'].to_i] ||= {}
        assignee_contact_counts[row['account_id'].to_i][user] = row['contacts_count'].to_i
        assignee_contact_counts
      end
    end

    def without_contacts
      sql = <<-sql
        (
          SELECT COUNT("contacts"."id")
          FROM "contacts"
            INNER JOIN "jobs" ON "jobs"."contact_id" = "contacts"."id" AND "jobs"."account_id" = "accounts"."id"
          WHERE "contacts"."deleted_at" IS NULL
            AND "jobs"."deleted_at" IS NULL
        ) = 0
      sql

      where(sql)
    end

    def with_contacts_assigned_to(user_id)
      user_id = user_id.id if user_id.is_a?(User)

      sql = <<-sql
        (
          SELECT COUNT("contacts"."id")
          FROM "contacts"
            INNER JOIN "jobs" ON "jobs"."contact_id" = "contacts"."id" AND "jobs"."account_id" = "accounts"."id"
          WHERE "contacts"."assignee_id" = #{user_id}
            AND "contacts"."deleted_at" IS NULL
            AND "jobs"."deleted_at" IS NULL
        ) > 0
      sql

      where(sql)
    end

  private

    def for_association(association, *record_ids)
      association_class = association.classify.constantize
      foreign_key = :"#{association.singularize}_id"
      assignments_table_name = :"account_#{association.singularize}_assignments"

      if record_ids.present?
        records = record_ids.first.is_a?(association_class) ? record_ids : association_class.find(record_ids)
        record_ids = records.map(&:subtree_ids).flatten.uniq
      end

      if record_ids.any?
        where("id IN (SELECT account_id FROM #{assignments_table_name} WHERE #{foreign_key} IN (?))", record_ids)
      else
        where("(SELECT COUNT(*) FROM #{assignments_table_name} WHERE account_id = accounts.id) = 0")
      end
    end

    def method_missing(name, *args, &block)
      if name =~ tag_scope_regexp
        for_association($~[1].pluralize, *args.compact)
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      name =~ tag_scope_regexp || super
    end

    def tag_scope_regexp
      tag_types = %i[regions topics]
      /\Afor_(#{tag_types.map { |tag_type| tag_type.to_s.singularize }.join('|')})\z/
    end

  end

  def has_account_connections?
    account_connections.any? || inverse_account_connections.any?
  end

  def has_alternative_names?
    alternative_names.any?
  end

  def todos
    activities.planned
  end

  def open_opportunities
    opportunities.open
  end

  def parent_name
    parent.try(:name)
  end

  def reject_connection?(attributes)
    attributes[:id].blank? && attributes[:connection_id].blank?
  end

private

  def cache_regions_and_topics
    self.cached_regions = regions.map { |region| { :id => region.id, :full_name => region.decorate.full_name } }
    self.cached_topics = topics.map { |topic| { :id => topic.id, :full_name => topic.decorate.full_name } }
  end

  def delete_pending_opportunities
    opportunities.pending.destroy_all
  end

  def parent_not_self
    if id == parent_id
      message = 'NDA'
      errors.add(:parent_id, message)
      errors.add(:parent_name, message)
    end
  end

end
