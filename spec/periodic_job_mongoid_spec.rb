# frozen_string_literal: true

RSpec.describe PeriodicJob do
  let(:scheduler) { subject }
  let(:counts) { Hash.new 0 }

  it "has a version number" do
    expect(PeriodicJob::VERSION).not_to be nil
  end
end