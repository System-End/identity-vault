require 'rails_helper'

RSpec.describe "public_activity/program/_update.html.erb", type: :view do
  let(:identity) { create(:identity) }
  let(:program)  { create(:program) }

  let(:activity) do
    PublicActivity::Activity.new(
      trackable: program,
      trackable_type: 'Program',
      trackable_id: program.id,
      owner: identity,
      owner_type: 'Identity',
      key: 'program.change',
      parameters: { changes: { name: { from: 'Old', to: 'New App Name' } } }
    )
  end

  it "renders the update partial without error and shows the update message" do
    render partial: "public_activity/program/update", locals: { activity: activity }

    # The partial's static text should appear in the output
    expect(rendered).to include("updated app settings")
  end
end
