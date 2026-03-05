require 'rails_helper'

RSpec.describe AuditLogsController, type: :controller do
  let(:identity) { create(:identity) }
  let(:program)  { create(:program) }

  before do
    # Stub controller helper to use our test identity
    allow(controller).to receive(:current_identity).and_return(identity)
  end

  it "excludes Program trackables and includes identity/verification/breakglass related activities" do
    # Program activity (should be excluded)
    program_activity = PublicActivity::Activity.create!(
      trackable: program,
      key: 'program.change',
      owner: identity,
      owner_type: 'Identity',
      created_at: 2.minutes.ago
    )

    # Owner activity (should be included) - attach to Identity as trackable to satisfy validations
    owner_activity = PublicActivity::Activity.create!(
      trackable_type: 'Identity',
      trackable_id: identity.id,
      owner: identity,
      owner_type: 'Identity',
      key: 'identity.owner_action',
      created_at: 3.minutes.ago
    )

    # Recipient activity (should be included) - attach to Identity as trackable to satisfy validations
    recipient_activity = PublicActivity::Activity.create!(
      trackable_type: 'Identity',
      trackable_id: identity.id,
      recipient: identity,
      recipient_type: 'Identity',
      key: 'identity.recipient_action',
      created_at: 4.minutes.ago
    )

    # Identity trackable activity (should be included)
    identity_trackable_activity = PublicActivity::Activity.create!(
      trackable_type: 'Identity',
      trackable_id: identity.id,
      key: 'identity.trackable_action',
      created_at: 5.minutes.ago
    )

    # Prepare a verification id and make the controller think the identity has it.
    verification_id = 999_001
    # Create the activity without validating presence of the actual Verification record.
    # This avoids validation errors in tests when we don't have a Verification model instance.
    verification_activity = PublicActivity::Activity.new(
      trackable_type: 'Verification',
      trackable_id: verification_id,
      key: 'verification.approve',
      created_at: 6.minutes.ago
    )
    verification_activity.save(validate: false)
    # Stub identity.verifications.pluck(:id) to return our verification_id
    fake_verifications = double("verifications", pluck: [ verification_id ])
    allow(identity).to receive(:verifications).and_return(fake_verifications)

    # Prepare a document id and break-glass id and stub the BreakGlassRecord lookup
    doc_id = 42
    break_id = 7
    fake_documents = double("documents", pluck: [ doc_id ])
    allow(identity).to receive(:documents).and_return(fake_documents)
    fake_breakglass_relation = double("breakglass_where", pluck: [ break_id ])
    allow(BreakGlassRecord).to receive(:where)
      .with(break_glassable_type: "Identity::Document", break_glassable_id: [ doc_id ])
      .and_return(fake_breakglass_relation)

    breakglass_activity = PublicActivity::Activity.new(
      trackable_type: 'BreakGlassRecord',
      trackable_id: break_id,
      key: 'break_glass.opened',
      created_at: 7.minutes.ago
    )
    # Create without validating associated BreakGlassRecord presence (synthetic test record)
    breakglass_activity.save(validate: false)

    get :index

    activities = controller.instance_variable_get(:@activities)
    expect(activities).to be_present

    keys = activities.map(&:key)

    expect(keys).to include('identity.owner_action')
    expect(keys).to include('identity.recipient_action')
    expect(keys).to include('identity.trackable_action')
    expect(keys).to include('verification.approve')
    expect(keys).to include('break_glass.opened')

    # Program change must not be present
    expect(keys).not_to include('program.change')
  end
end
