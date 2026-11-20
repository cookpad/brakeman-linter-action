# frozen_string_literal: true

require "./spec/spec_helper"

describe WorkflowCommand do
  it "builds a workflow command" do
    expect(described_class.build(:warning, "Something happened")).to eq("::warning::Something happened")
  end

  it "encodes newlines so the message can't start another command" do
    expect(described_class.build(:error, "first\n::add-mask::secret\r\nlast")).
      to eq("::error::first%0A::add-mask::secret%0D%0Alast")
  end

  it "encodes percent signs so they aren't read as encodings" do
    expect(described_class.build(:error, "100%0A done")).to eq("::error::100%250A done")
  end
end
