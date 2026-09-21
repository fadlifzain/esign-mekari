module Envelopes
  class ChargePreview
    TOP_LEVEL_KEYS = %w[order_mode recipients fields].freeze
    RECIPIENT_BASE_KEYS = %w[name email signature_count meterai_count].freeze
    FIELD_KEYS = %w[id kind recipient_email page x y].freeze

    def initialize(envelope_id:, payload:, workspace_id: Current.workspace_id, store: EnvelopeStore.instance)
      @envelope_id = envelope_id
      @payload = payload
      @workspace_id = workspace_id
      @store = store
    end

    def call
      shape = validate_payload_shape
      return shape unless shape.ok?

      envelope = @store.find(@envelope_id)
      if envelope.nil? || envelope.workspace_id != @workspace_id
        return ServiceResult.error(code: "ENVELOPE_NOT_FOUND", message: "Envelope not found", http_status: 404)
      end

      order_mode = @payload["order_mode"]
      unless %w[parallel sequential].include?(order_mode)
        return error("ORDER_MODE_INVALID", "order_mode must be parallel or sequential")
      end

      parsed = []
      Array(@payload["recipients"]).each do |row|
        result = parse_recipient(row, order_mode)
        return result unless result.ok?

        parsed << result.value
      end

      if Validation::Recipients.duplicate_emails?(parsed.map { |row| row[:email] })
        return error("DUPLICATE_RECIPIENT_EMAIL", "Each recipient email must be unique")
      end

      if order_mode == "sequential"
        steps = parsed.map { |row| row[:step] }
        unless Validation::Recipients.consecutive_steps?(steps)
          return error("STEP_SEQUENCE_INVALID", "Steps must start at 1 and increase without gaps")
        end
      end

      parsed.each do |row|
        if row[:meterai_count] > row[:signature_count]
          return error(
            "METERAI_EXCEEDS_SIGNATURE",
            "eMeterai cannot exceed signatures for #{row[:email]}",
            recipient_email: row[:email]
          )
        end
      end

      if order_mode == "sequential"
        parsed.each do |row|
          next unless row[:meterai_count].positive? && row[:step] != 1

          label = row[:name].presence || row[:email]
          return error(
            "METERAI_NOT_IN_FIRST_STEP",
            "#{label} has eMeterai but is in step #{row[:step]}. Duty stamps must be affixed in step 1.",
            recipient_email: row[:email]
          )
        end
      end

      fields_result = validate_fields(parsed)
      return fields_result unless fields_result.ok?

      fields = fields_result.value
      totals = Pricing::Calculator.totals(parsed)

      if parsed.size > SignConfig::SIGNATURE_QUOTA
        return error(
          "INSUFFICIENT_SIGNATURE_QUOTA",
          "This document needs #{parsed.size} recipient rows, but only #{SignConfig::SIGNATURE_QUOTA} remain"
        )
      end

      if totals[:total_meterai] > SignConfig::METERAI_QUOTA
        return error(
          "INSUFFICIENT_METERAI_QUOTA",
          "This document needs #{totals[:total_meterai]} eMeterai, but only #{SignConfig::METERAI_QUOTA} remain"
        )
      end

      steps = grouped_steps(parsed, order_mode)
      ServiceResult.ok({
        order_mode: order_mode,
        steps: steps,
        recipient_count: parsed.size,
        total_signatures: totals[:total_signatures],
        total_meterai: totals[:total_meterai],
        field_count: fields.size,
        price: {
          signature: Pricing::Money.from_cents(SignConfig::SIGNATURE_PRICE_CENTS).to_api,
          meterai: Pricing::Money.from_cents(SignConfig::METERAI_PRICE_CENTS).to_api
        },
        charges: {
          signature: totals[:signature_charge].to_api,
          meterai: totals[:meterai_charge].to_api
        },
        total_charge: totals[:total_charge].to_api,
        quota: {
          signature: SignConfig::SIGNATURE_QUOTA,
          meterai: SignConfig::METERAI_QUOTA
        },
        quota_remaining: totals[:quota_remaining]
      })
    end

    private

    def validate_payload_shape
      return error("PAYLOAD_INVALID", "JSON body must be an object") unless @payload.is_a?(Hash)

      extra = Validation::Payload.extra_keys(@payload, TOP_LEVEL_KEYS)
      return unknown_field(extra.first) if extra.any?

      recipients = @payload["recipients"]
      unless recipients.is_a?(Array) && recipients.size.between?(1, SignConfig::MAX_RECIPIENTS)
        return error("RECIPIENT_COUNT_INVALID", "Provide between 1 and #{SignConfig::MAX_RECIPIENTS} recipients")
      end

      if @payload.key?("fields") && !@payload["fields"].is_a?(Array)
        return error("PAYLOAD_INVALID", "fields must be an array")
      end

      ServiceResult.ok(true)
    end

    def parse_recipient(row, order_mode)
      return error("RECIPIENT_INVALID", "Each recipient must be an object") unless row.is_a?(Hash)

      allowed = RECIPIENT_BASE_KEYS
      allowed += %w[step] if order_mode == "sequential"
      extra = Validation::Payload.extra_keys(row, allowed)
      return unknown_field(extra.first) if extra.any?

      unless Validation::Recipients.valid_name?(row["name"]) && Validation::Recipients.valid_email?(row["email"])
        return error("RECIPIENT_INVALID", "Each recipient needs a name and a valid email")
      end

      unless Validation::Recipients.integer_in?(row["signature_count"], SignConfig::SIGNATURE_MIN, SignConfig::SIGNATURE_MAX)
        return error("SIGNATURE_COUNT_INVALID", "signature_count must be an integer between 1 and 20")
      end

      meterai_count = row.key?("meterai_count") ? row["meterai_count"] : 0
      unless Validation::Recipients.integer_in?(meterai_count, SignConfig::METERAI_MIN, SignConfig::METERAI_MAX)
        return error("METERAI_COUNT_INVALID", "meterai_count must be an integer between 0 and 3")
      end

      parsed = {
        name: row["name"].strip,
        email: row["email"].strip,
        signature_count: row["signature_count"],
        meterai_count: meterai_count
      }
      parsed[:step] = row["step"] if order_mode == "sequential"
      ServiceResult.ok(parsed)
    end

    def validate_fields(recipients)
      return ServiceResult.ok([]) unless @payload.key?("fields")

      seen_ids = []
      parsed_fields = []

      @payload["fields"].each do |field|
        return error("PAYLOAD_INVALID", "Each field must be an object") unless field.is_a?(Hash)

        extra = Validation::Payload.extra_keys(field, FIELD_KEYS)
        return unknown_field(extra.first) if extra.any?

        id = field["id"]
        unless id.is_a?(String) && id.present?
          return error("FIELD_ID_DUPLICATE", "Each field needs a unique id")
        end
        if seen_ids.include?(id)
          return error("FIELD_ID_DUPLICATE", "Field id #{id} is duplicated")
        end
        seen_ids << id

        kind = field["kind"]
        unless SignConfig::FIELD_SIZES.key?(kind)
          return error("FIELD_KIND_INVALID", "kind must be signature or meterai")
        end

        unless field["page"] == 1
          return error("FIELD_PAGE_INVALID", "page must be 1")
        end

        x = field["x"]
        y = field["y"]
        unless Validation::Fields.in_bounds?(kind, x, y)
          return error("FIELD_OUT_OF_BOUNDS", "The #{kind} field is outside the allowed area")
        end

        parsed_fields << {
          id: id,
          kind: kind,
          recipient_email: field["recipient_email"],
          page: field["page"],
          x: x,
          y: y
        }
      end

      recipients_by_email = recipients.index_by { |row| Validation::Recipients.normalize_email(row[:email]) }
      counts = Hash.new { |hash, key| hash[key] = Hash.new(0) }

      parsed_fields.each do |field|
        key = Validation::Recipients.normalize_email(field[:recipient_email])
        unless recipients_by_email.key?(key)
          return error("FIELD_UNKNOWN_RECIPIENT", "No recipient matches #{field[:recipient_email]}")
        end

        counts[key][field[:kind]] += 1
      end

      recipients.each do |row|
        key = Validation::Recipients.normalize_email(row[:email])
        signature_fields = counts[key]["signature"]
        meterai_fields = counts[key]["meterai"]
        if signature_fields != row[:signature_count] || meterai_fields != row[:meterai_count]
          return error(
            "FIELD_COUNT_MISMATCH",
            "Fields must match signature_count and meterai_count for #{row[:email]}"
          )
        end
      end

      ServiceResult.ok(parsed_fields)
    end

    def grouped_steps(recipients, order_mode)
      grouped = recipients.group_by { |row| order_mode == "parallel" ? 1 : row[:step] }
      grouped.keys.sort.map do |step|
        {
          step: step,
          recipient_emails: grouped[step].map { |row| row[:email] }
        }
      end
    end

    def unknown_field(key)
      error("UNKNOWN_FIELD", "Unknown field #{key}")
    end

    def error(code, message, **extra)
      ServiceResult.error(code: code, message: message, **extra)
    end
  end
end
