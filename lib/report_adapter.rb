# frozen_string_literal: true

# https://developer.github.com/v3/checks/runs/#output-object
class ReportAdapter
  class << self
    CONCLUSION_TYPES = { failure: "failure", success: "success" }.freeze
    ANNOTATION_LEVEL = { notice: "notice", warning: "warning", failure: "failure" }.freeze
    MAX_SUMMARY_BYTES = 65_535
    OMITTED_NOTICE_RESERVE = 100

    def conslusion(report)
      return CONCLUSION_TYPES[:failure] if security_warnings(report) > 0 || scan_errors(report).any?

      CONCLUSION_TYPES[:success]
    end

    def summary(report)
      warnings = "**Brakeman Report**:\n#{security_warnings(report)} security warnings\n#{check_table(report)}"
      warnings + errors_list(report, MAX_SUMMARY_BYTES - warnings.bytesize)
    end

    def annotations(report)
      report["warnings"].map do |error|
        {
          "path" => error["file"],
          "start_line" => error["line"],
          "end_line" => error["line"],
          "annotation_level" => ANNOTATION_LEVEL[:warning],
          "title" => "#{error['confidence']} - #{error['check_name']}",
          "message" => error["message"]
        }
      end
    end

    private

      def check_table(report)
        uniq_checks(report).reduce("") { |memo, check| memo + "- [#{check[:check_name]}](#{check[:link]})\n" }
      end

      def uniq_checks(report)
        report["warnings"].map { |w| { check_name: w["check_name"], link: w["link"] } }.uniq { |w| w[:check_name] }
      end

      def errors_list(report, max_bytes)
        errors = scan_errors(report)
        return "" if errors.empty?

        text = "\n**#{errors.size} scan error(s)** (Brakeman could not fully scan these):\n"
        errors.each_with_index do |error, shown|
          line = "- #{error['error']}\n"
          if text.bytesize + line.bytesize + OMITTED_NOTICE_RESERVE > max_bytes
            return text << "...and #{errors.size - shown} more scan error(s) not shown\n"
          end

          text << line
        end
        text
      end

      def scan_errors(report)
        report.fetch("errors", [])
      end

      def security_warnings(report)
        report["scan_info"]["security_warnings"]
      end
  end
end
