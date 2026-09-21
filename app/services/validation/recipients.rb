module Validation
  module Recipients
    module_function

    def valid_name?(name)
      name.is_a?(String) && name.strip != ""
    end

    def valid_email?(email)
      return false unless email.is_a?(String)

      local, domain, *rest = email.strip.split("@", -1)
      return false unless rest.empty? && local.present? && domain.present?

      parts = domain.split(".", -1)
      parts.length >= 2 && parts.all?(&:present?)
    end

    def normalize_email(email)
      email.to_s.strip.downcase
    end

    def duplicate_emails?(emails)
      normalized = emails.map { |email| normalize_email(email) }
      normalized.size != normalized.uniq.size
    end

    def integer_in?(value, min, max)
      value.is_a?(Integer) && value.between?(min, max)
    end

    def consecutive_steps?(steps)
      return false unless steps.all? { |step| step.is_a?(Integer) && step >= 1 }

      unique = steps.uniq.sort
      unique.first == 1 && unique == (1..unique.last).to_a
    end

    def renormalize_steps(recipients)
      unique = recipients.map { |row| row[:step] || row["step"] }.uniq.sort
      mapping = unique.each_with_index.to_h { |step, index| [ step, index + 1 ] }

      recipients.map do |row|
        current = row[:step] || row["step"]
        row.merge(row.key?(:step) ? { step: mapping[current] } : { "step" => mapping[current] })
      end
    end

    def clamp_signature_count(raw)
      parse_int(raw, SignConfig::SIGNATURE_MIN).clamp(SignConfig::SIGNATURE_MIN, SignConfig::SIGNATURE_MAX)
    end

    def clamp_meterai_count(raw, signature_count)
      max = [ SignConfig::METERAI_MAX, signature_count ].min
      parse_int(raw, SignConfig::METERAI_MIN).clamp(SignConfig::METERAI_MIN, max)
    end

    def parse_int(raw, fallback)
      return raw if raw.is_a?(Integer)
      return Integer(raw) if raw.is_a?(String) && raw.strip.match?(/\A-?\d+\z/)

      fallback
    end
    private_class_method :parse_int
  end
end
