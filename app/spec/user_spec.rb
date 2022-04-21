require 'spec_helper'

describe User do
  it_behaves_like "a nameable"

  it { is_expected.to normalize_attribute(:email) }
end

describe User, "instance methods" do
  let(:user) { create(:user) }

  describe "#update_and_confirm" do
    it "updates the given attributes and confirms the user" do
      user.update_and_confirm(:first_name => 'NDA', :last_name => 'NDA')

      expect(user.first_name).to eql('NDA')
      expect(user.last_name).to eql('NDA')
      expect(user).to be_confirmed
    end

    it "doesn't confirm the user if the update fails" do
      user.update_and_confirm(:last_name => nil)

      expect(user).to_not be_confirmed
    end
  end

  describe "#active_for_authentication?" do
    subject(:user) { build(:user, :confirmed) }

    it "returns true if the user wasn't deactivated" do
      expect(user).to be_active_for_authentication
    end

    it "returns fase if the user was deactivated" do
      user.deactivated_at = 1.second.ago

      expect(user).to_not be_active_for_authentication
    end
  end

  describe "#activate" do
    subject(:user) { create(:user, :deactivated) }

    it "unsets the user's deactivation time" do
      user.activate

      expect(user.deactivated_at).to be_nil
    end
  end

  describe "#deactivate" do
    it "sets the user's deactivation time" do
      user.deactivate

      expect(user.deactivated_at).to be_within(1.second).of(Time.current)
    end

    it "reassigns the user's data to another user" do
      other_user = create(:user)

      contact = create(:contact, :assignee => user)
      todo = create(:todo, :user => user)
      completed_activity = create(:activity, :completed, :user => user, :contact => contact)
      open_opportunity = create(:opportunity, :user => user)
      won_opportunity = create(:opportunity, :won, :user => user)
      lost_opportunity = create(:opportunity, :lost, :user => user)

      stays_with_deactivated_user = [completed_activity, won_opportunity, lost_opportunity]
      gets_reassigned = [contact, todo, open_opportunity]

      user.deactivate(reassign_data_to: other_user)

      stays_with_deactivated_user.each do |record|
        expect(record.reload.user).to eq user
      end

      gets_reassigned.each do |record|
        expect(record.reload.user).to eq other_user
      end
    end

    it "doesn't change the deactivation time for an already deactivated user" do
      user.deactivated_at = 1.second.ago

      expect { user.deactivate }.to_not change { user.deactivated_at }
    end
  end

  describe "group methods" do
    let(:group) { create(:group) }
    let!(:other_user) { create(:user, :group => group) }

    describe "#in_same_group_as?" do
      it "returns true if the user is in the same group as another" do
        user.update_attribute(:group, group)

        expect(user).to be_in_same_group_as(other_user)
      end

      it "returns false if the user is in another group" do
        user.update_attribute(:group, create(:group))

        expect(user).to_not be_in_same_group_as(other_user)
      end

      it "returns false if the user is not in a group at all" do
        user.update_attribute(:group, nil)

        expect(user).to_not be_in_same_group_as(other_user)
      end

      it "returns false if the given user is nil" do
        user.update_attribute(:group, group)

        expect(user).to_not be_in_same_group_as(nil)
      end
    end

    describe "#own_and_groups_user_ids" do
      it "returns the user's id if the user is not in a group" do
        user.update_attribute(:group, nil)

        expect(user.own_and_groups_user_ids).to match_array([user.id])
      end

      it "returns the user's own as well as their group members' ids" do
        user.update_attribute(:group, group)

        expect(user.own_and_groups_user_ids).to match_array([user.id, other_user.id])
      end
    end
  end

  describe "#destroy" do
    it "unassigns contacts, opportunities and activities" do
      contact = create(:contact, :assignee => user)
      opportunity = create(:opportunity, :user => user)
      todo = create(:todo, :user => user)
      activity = create(:activity, :user => user)

      user.destroy

      expect(contact.reload.assignee_id).to be_blank
      expect(opportunity.reload.user_id).to be_blank
      expect(todo.reload.user_id).to be_blank
      expect(activity.reload.user_id).to be_blank
    end
  end
end
