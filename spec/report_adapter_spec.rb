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

  context "when the scan errors exceed GitHub's summary limit" do
    let(:report_with_many_errors) do
      errors = Array.new(2000) { |i| { "error" => "app/models/model_#{i}.rb :: #{'x' * 100}", "location" => "x.rb:1" } }
      JSON(File.read("./spec/fixtures/no_findings_report.json")).merge("errors" => errors)
    end

    it "keeps the summary within 65,535 characters" do
      expect(adapter.summary(report_with_many_errors).length).to be <= 65_535
    end

    it "keeps the summary within 65,535 bytes when errors contain multibyte characters" do
      report_with_many_errors["errors"].each { |error| error["error"] = error["error"].tr("x", "é") }
      expect(adapter.summary(report_with_many_errors).bytesize).to be <= 65_535
    end

    it "keeps the total error count and says how many were left out" do
      expect(adapter.summary(report_with_many_errors)).
        to include("**2000 scan error(s)**").and match(/\.\.\.and \d+ more scan error\(s\) not shown/)
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
