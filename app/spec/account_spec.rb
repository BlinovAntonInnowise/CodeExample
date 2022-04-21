require 'spec_helper'

describe Account do
  it { is_expected.to normalize_attribute(:name) }
  it { is_expected.to normalize_attribute(:notes) }

  fields = {
    :landline => Phone,
    :fax => Phone,
    :work_email_address => EmailAddress,
    :website => Website,
    :address => Address
  }
  it_behaves_like "an object with contact details", fields
end

describe Account, "validations" do
  let(:account) { build(:account) }

  it "requires a name" do
    account.name = nil

    expect(account).to_not be_valid
    expect(account).to have(1).error_on(:name)
  end

  it "doesn't allow parent to be self" do
    account = create(:account)

    account.parent_id = account.id

    expect(account).to_not be_valid
    expect(account).to have(1).error_on(:parent_id)
    expect(account).to have(1).error_on(:parent_name)
  end
end

describe Account, "callbacks" do
  describe "#cache_regions_and_topics" do
    it "caches the regions when saved" do
      region_1 = create(:region, :name => 'Region')
      region_2 = create(:region, :name => 'Child', :parent => create(:region, :name => 'Parent'))
      account = build(:account, :regions => [region_1, region_2])

      account.save

      expect(account.reload.cached_regions).to eq [
        { 'id' => region_1.id, 'full_name' => 'Region' },
        { 'id' => region_2.id, 'full_name' => 'Parent > Child' }
      ]
    end

    it "caches the topics when saved" do
      topic_1 = create(:topic, :name => 'Topic')
      topic_2 = create(:topic, :name => 'Child', :parent => create(:topic, :name => 'Parent'))
      account = build(:account, :topics => [topic_1, topic_2])

      account.save

      expect(account.reload.cached_topics).to eq [
        { 'id' => topic_1.id, 'full_name' => 'Topic' },
        { 'id' => topic_2.id, 'full_name' => 'Parent > Child' }
      ]
    end
  end
end

describe Account, "scopes" do
  %w[region topic].each do |tag_type|
    scope = "for_#{tag_type}"

    describe "##{scope}" do
      let(:parent_tag) { create(tag_type) }
      let(:tag) { create(tag_type, :parent => parent_tag) }
      let(:other_tag) { create(tag_type, :parent => parent_tag) }
      let!(:account_1) { create(:account, tag_type.pluralize => [tag]) }
      let!(:account_2) { create(:account, tag_type.pluralize => [other_tag]) }

      it "finds accounts assigned to the specific #{tag_type}" do
        expect(Account.public_send(scope, tag)).to eq [account_1]
      end

      it "finds accounts assigned to a child #{tag_type}" do
        expect(Account.public_send(scope, parent_tag)).to match_array [account_1, account_2]
      end

      it "finds accounts without a #{tag_type}" do
        account_without_tag = create(:account, tag_type.pluralize => [])

        expect(Account.public_send(scope, nil)).to eq [account_without_tag]
      end

      it "doesnt include the same account multiple times when assigned to multiple child tags of the same parent" do
        account_1.update!(tag_type.pluralize => [tag, other_tag])
        account_2.update!(tag_type.pluralize => [tag, other_tag])

        expect(Account.public_send(scope, parent_tag)).to match_array [account_1, account_2]
      end
    end
  end

  context "combining tag scopes" do
    let(:region) { create(:region) }
    let(:topic) { create(:topic) }
    let!(:account_only_assigned_to_region) { create(:account, :regions => [region]) }
    let!(:account_only_assigned_to_topic) { create(:account, :topics => [topic]) }
    let!(:account) { create(:account, :regions => [region], :topics => [topic]) }

    it "finds accounts assigned to all given tag scopes" do
      expect(Account.for_region(region).for_topic(topic)).to eq [account]
    end
  end

  describe ".without_contacts" do
    it "returns all accounts without contacts" do
      account = create(:account)
      create(:contact, :accounts => [create(:account)])

      expect(Account.without_contacts).to eq [account]
    end

    it "handles deleted contacts and jobs correctly" do
      account_1 = create(:account)
      account_2 = create(:account)
      account_3 = create(:account)
      create(:contact, :accounts => [account_1]).destroy
      create(:contact, :accounts => [account_2]).jobs.destroy_all
      create(:contact, :accounts => [account_3]).destroy
      create(:contact, :accounts => [account_3]).jobs.destroy_all
      create(:contact, :accounts => [account_3])

      expect(Account.without_contacts).to match_array [account_1, account_2]
    end
  end

  describe ".with_contacts_assigned_to" do
    let(:user) { create(:user) }

    it "returns all accounts with contacts assigned to the given user" do
      account_1 = create(:account)
      account_2 = create(:account)
      create(:contact, :accounts => [account_1], :assignee => user)
      create(:contact, :accounts => [account_2])

      expect(Account.with_contacts_assigned_to(user.id)).to eq [account_1]
    end

    it "doesnt include accounts with multiple assigned contacts multiple times" do
      account = create(:account)
      create(:contact, :accounts => [account], :assignee => user)
      create(:contact, :accounts => [account], :assignee => user)

      expect(Account.with_contacts_assigned_to(user.id)).to eq [account]
    end

    it "handles deleted contacts and jobs correctly" do
      account_1 = create(:account)
      account_2 = create(:account)
      account_3 = create(:account)
      create(:contact, :accounts => [account_1], :assignee => user).destroy
      create(:contact, :accounts => [account_2], :assignee => user).jobs.destroy_all
      create(:contact, :accounts => [account_3], :assignee => user).destroy
      create(:contact, :accounts => [account_3], :assignee => user).jobs.destroy_all
      create(:contact, :accounts => [account_3], :assignee => user)

      expect(Account.with_contacts_assigned_to(user.id)).to eq [account_3]
    end
  end
end

describe Account, "instance methods" do
  subject(:account) { create(:account) }

  describe "#destroy" do
    it "(soft-)deletes jobs but doesn't delete contacts" do
      contact_1 = create(:job, account: account).contact
      contact_2 = create(:job, account: account).contact

      expect { account.destroy }.to change(Job, :count).by(-2)
      expect([contact_1, contact_2].all? { |contact| contact.reload.persisted? }).to eq true
    end

    it "keeps finalized (won/lost) opportunities" do
      opportunity_1 = create(:opportunity, :won, account: account)
      opportunity_2 = create(:opportunity, :lost, account: account)

      expect { account.destroy }.to_not change(Opportunity, :count)
    end

    it "deletes pending opportunities" do
      opportunity = create(:opportunity, :proposal, account: account)

      expect { account.destroy }.to change(Opportunity, :count).by(-1)
      expect { opportunity.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "(soft-)deletes taggings"

    it "deletes account list assignments but keeps the lists" do
      account_list_1 = create(:account_list_assignment, account: account).account_list
      account_list_2 = create(:account_list_assignment, account: account).account_list

      expect { account.destroy }.to change(AccountListAssignment, :count).by(-2)
      expect([account_list_1, account_list_2].all? { |account_list| account_list.reload.persisted? }).to eq true
    end

    it "(soft-)deletes account connections but not the connected account" do
      account_2 = create(:account_connection, account: account).connection
      account_3 = create(:account_connection, account: account).connection

      expect { account.destroy }.to change(AccountConnection, :count).by(-2)
      expect([account_2, account_3].all? { |account| account.reload.persisted? }).to eq true
    end

    it "doesn't delete phone numbers" do
      phone = create(:phone, phoneable: account)

      expect { account.destroy }.to_not change(Phone, :count)
      expect { phone.reload }.to_not raise_error
    end

    it "doesn't delete email addresses" do
      email_address = create(:email_address, emailable: account)

      expect { account.destroy }.to_not change(EmailAddress, :count)
      expect { email_address.reload }.to_not raise_error
    end

    it "doesn't delete addresses" do
      address = create(:address, addressable: account)

      expect { account.destroy }.to_not change(Address, :count)
      expect { address.reload }.to_not raise_error
    end
  end
end
