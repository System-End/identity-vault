require 'rails_helper'

RSpec.describe DeveloperAppsController, type: :controller do
  let(:identity) { create(:identity) }
  let(:program)  { create(:program) }

  before do
    # Make controller act as the given identity
    allow(controller).to receive(:current_identity).and_return(identity)
  end

  describe "#activity_log" do
    it "shows activities whose trackable is the program and excludes unrelated activities" do
      # Program-scoped activities (should be included)
      prog_create = PublicActivity::Activity.create!(
        trackable: program,
        key: 'program.create',
        owner: identity,
        owner_type: 'Identity',
        created_at: 5.minutes.ago
      )

      prog_change = PublicActivity::Activity.create!(
        trackable: program,
        key: 'program.change',
        owner: identity,
        owner_type: 'Identity',
        created_at: 4.minutes.ago
      )

      # Activity about the identity (should NOT be included in the program activity log)
      identity_activity = PublicActivity::Activity.create!(
        trackable_type: 'Identity',
        trackable_id: identity.id,
        key: 'identity.update',
        owner: identity,
        owner_type: 'Identity',
        created_at: 3.minutes.ago
      )

      # An activity for a different program (should NOT be included)
      other_program = create(:program)
      other_prog_activity = PublicActivity::Activity.create!(
        trackable: other_program,
        key: 'program.change',
        owner: identity,
        owner_type: 'Identity',
        created_at: 2.minutes.ago
      )

      # Request the activity log for the program
      get :activity_log, params: { id: program.id }

      activities = controller.instance_variable_get(:@activities)
      expect(activities).to be_present

      keys = activities.map(&:key)

      # Program activities for this program must be present
      expect(keys).to include('program.create')
      expect(keys).to include('program.change')

      # Unrelated activities must not be present
      expect(keys).not_to include('identity.update')
      expect(keys).not_to include(other_prog_activity.key)

      # Ensure all returned activities are actually tied to the requested program
      expect(activities.map(&:trackable_id).uniq).to eq([ program.id ])
      expect(activities.map(&:trackable_type).uniq).to eq([ 'Program' ])
    end
  end
end
