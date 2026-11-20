# frozen_string_literal: true

require "./spec/spec_helper"

describe ReportAdapter do
  let(:brakeman_report) do
    JSON(File.read("./spec/fixtures/report.json"))
  end

  let(:spec_annotations) do
    JSON(File.read("./spec/fixtures/output/annotations.json"))
  end

  let(:spec_summary) do
    File.read("./spec/fixtures/output/summary.md")
  end

  let(:adapter) { described_class }

  it ".conclusion" do
    result = adapter.conslusion(brakeman_report)
    expect(result).to eq("failure")
  end

  context "when the scan has errors but no warnings" do
    let(:report_with_errors) do
      JSON(File.read("./spec/fixtures/no_findings_report.json")).merge(
        "errors" => [{ "error" => "app/models/user.rb:3 :: parse error on value \"end\"", "location" => "x.rb:1" }]
      )
    end

    it "concludes as a failure" do
      expect(adapter.conslusion(report_with_errors)).to eq("failure")
    end

    it "lists the scan errors in the summary" do
      expect(adapter.summary(report_with_errors)).
        to include("**1 scan error(s)**", "- app/models/user.rb:3 :: parse error on value \"end\"")
    end
  end

  it ".summary" do
    result = adapter.summary(brakeman_report)
    expect(result).to eq(spec_summary)
  end

  it ".annotations" do
    result = adapter.annotations(brakeman_report)
    expect(result).to eq(spec_annotations)
  end
end
