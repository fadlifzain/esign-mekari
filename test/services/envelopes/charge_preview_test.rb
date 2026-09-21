require "test_helper"

class Envelopes::ChargePreviewTest < ActiveSupport::TestCase
  setup do
    @envelope_id = upload_envelope
  end

  test "sequential preview with meterai matches the case 2 contract" do
    recipients = [
      { "name" => "Rina Halim", "email" => "rina.halim@example.test", "signature_count" => 2, "meterai_count" => 1, "step" => 1 },
      { "name" => "Budi Santoso", "email" => "budi.santoso@example.test", "signature_count" => 1, "meterai_count" => 0, "step" => 2 }
    ]

    result = preview(
      "order_mode" => "sequential",
      "recipients" => recipients,
      "fields" => [
        { "id" => "f1", "kind" => "signature", "recipient_email" => "rina.halim@example.test", "page" => 1, "x" => 64, "y" => 224 },
        { "id" => "f2", "kind" => "signature", "recipient_email" => "rina.halim@example.test", "page" => 1, "x" => 64, "y" => 340 },
        { "id" => "f3", "kind" => "meterai", "recipient_email" => "rina.halim@example.test", "page" => 1, "x" => 360, "y" => 224 },
        { "id" => "f4", "kind" => "signature", "recipient_email" => "budi.santoso@example.test", "page" => 1, "x" => 64, "y" => 440 }
      ]
    )

    assert result.ok?
    body = result.value
    assert_equal "sequential", body[:order_mode]
    assert_equal [ { step: 1, recipient_emails: [ "rina.halim@example.test" ] }, { step: 2, recipient_emails: [ "budi.santoso@example.test" ] } ], body[:steps]
    assert_equal 2, body[:recipient_count]
    assert_equal 3, body[:total_signatures]
    assert_equal 1, body[:total_meterai]
    assert_equal 4, body[:field_count]
    assert_equal({ signature: "5000.00", meterai: "10000.25" }, body[:price])
    assert_equal({ signature: "15000.00", meterai: "10000.25" }, body[:charges])
    assert_equal "25000.25", body[:total_charge]
    assert_equal({ signature: 8, meterai: 3 }, body[:quota])
    assert_equal({ signature: 6, meterai: 2 }, body[:quota_remaining])
    assert_nil body[:preview_token]
  end

  test "parallel mode treats everyone as a single step and allows meterai" do
    recipients = [
      { "name" => "Rina Halim", "email" => "rina.halim@example.test", "signature_count" => 1, "meterai_count" => 1 },
      { "name" => "Budi Santoso", "email" => "budi.santoso@example.test", "signature_count" => 1, "meterai_count" => 0 }
    ]

    result = preview("order_mode" => "parallel", "recipients" => recipients)

    assert result.ok?
    assert_equal [ { step: 1, recipient_emails: [ "rina.halim@example.test", "budi.santoso@example.test" ] } ], result.value[:steps]
    assert_equal 1, result.value[:total_meterai]
  end

  test "parallel payloads must not include step" do
    result = preview(
      "order_mode" => "parallel",
      "recipients" => [
        { "name" => "Rina Halim", "email" => "rina.halim@example.test", "signature_count" => 1, "meterai_count" => 0, "step" => 1 }
      ]
    )

    assert_error result, "UNKNOWN_FIELD", 422
  end

  test "meterai_count cannot exceed that recipient signature_count" do
    result = preview(
      "order_mode" => "parallel",
      "recipients" => [
        { "name" => "Rina Halim", "email" => "rina.halim@example.test", "signature_count" => 1, "meterai_count" => 2 }
      ]
    )

    assert_error result, "METERAI_EXCEEDS_SIGNATURE", 422
    assert_equal "rina.halim@example.test", result.error[:recipient_email]
  end

  test "sequential meterai is only allowed in step 1 and names the recipient" do
    result = preview(
      "order_mode" => "sequential",
      "recipients" => [
        { "name" => "Rina Halim", "email" => "rina.halim@example.test", "signature_count" => 1, "meterai_count" => 0, "step" => 1 },
        { "name" => "Budi Santoso", "email" => "budi.santoso@example.test", "signature_count" => 1, "meterai_count" => 1, "step" => 2 }
      ]
    )

    assert_error result, "METERAI_NOT_IN_FIRST_STEP", 422
    assert_equal "budi.santoso@example.test", result.error[:recipient_email]
    assert_match(/Budi Santoso/, result.error[:message])
    assert_match(/step 2/, result.error[:message])
  end

  test "signature and meterai quota shortfalls are distinct errors" do
    signature = preview(
      "order_mode" => "parallel",
      "recipients" => (1..9).map { |index|
        { "name" => "Signer #{index}", "email" => "signer#{index}@example.test", "signature_count" => 1, "meterai_count" => 0 }
      }
    )
    assert_error signature, "INSUFFICIENT_SIGNATURE_QUOTA", 422
    assert_no_match(/eMeterai/, signature.error[:message])

    meterai = preview(
      "order_mode" => "parallel",
      "recipients" => [
        { "name" => "Rina Halim", "email" => "rina.halim@example.test", "signature_count" => 3, "meterai_count" => 3 },
        { "name" => "Budi Santoso", "email" => "budi.santoso@example.test", "signature_count" => 1, "meterai_count" => 1 }
      ]
    )
    assert_error meterai, "INSUFFICIENT_METERAI_QUOTA", 422
    assert_match(/eMeterai/, meterai.error[:message])
    assert_no_match(/signatures/, meterai.error[:message])
  end

  test "many stamps on few rows do not consume signature quota" do
    result = preview(
      "order_mode" => "parallel",
      "recipients" => [
        { "name" => "Rina Halim", "email" => "rina.halim@example.test", "signature_count" => 20, "meterai_count" => 0 },
        { "name" => "Budi Santoso", "email" => "budi.santoso@example.test", "signature_count" => 20, "meterai_count" => 0 }
      ]
    )

    assert result.ok?
    assert_equal 2, result.value[:recipient_count]
    assert_equal 40, result.value[:total_signatures]
    assert_equal({ signature: 6, meterai: 3 }, result.value[:quota_remaining])
  end

  test "eight recipient rows with extra stamps stay within signature quota" do
    result = preview(
      "order_mode" => "parallel",
      "recipients" => (1..8).map { |index|
        { "name" => "Signer #{index}", "email" => "signer#{index}@example.test", "signature_count" => 2, "meterai_count" => 0 }
      }
    )

    assert result.ok?
    assert_equal 8, result.value[:recipient_count]
    assert_equal 16, result.value[:total_signatures]
    assert_equal 0, result.value[:quota_remaining][:signature]
  end

  test "out of range meterai_count is METERAI_COUNT_INVALID" do
    [ -1, 4, 1.5, "1" ].each do |value|
      result = preview(
        "order_mode" => "parallel",
        "recipients" => [
          { "name" => "Rina Halim", "email" => "rina.halim@example.test", "signature_count" => 2, "meterai_count" => value }
        ]
      )
      assert_error result, "METERAI_COUNT_INVALID", 422
    end
  end

  test "unknown top-level fields are rejected before envelope lookup" do
    result = Envelopes::ChargePreview.new(
      envelope_id: "missing",
      payload: { "order_mode" => "parallel", "recipients" => [ rina ], "workspace_id" => "ws-b" }
    ).call

    assert_error result, "UNKNOWN_FIELD", 422
  end

  test "missing and foreign envelopes share one 404 body" do
    payload = { "order_mode" => "parallel", "recipients" => [ rina ] }
    missing = Envelopes::ChargePreview.new(envelope_id: "env_missing", payload: payload).call
    foreign = Envelopes::ChargePreview.new(envelope_id: "env_other", payload: payload).call

    assert_error missing, "ENVELOPE_NOT_FOUND", 404
    assert_equal missing.error, foreign.error
    assert_equal missing.http_status, foreign.http_status
  end

  test "validation order prefers payload shape, then auth, then order_mode" do
    unknown = Envelopes::ChargePreview.new(
      envelope_id: "env_other",
      payload: { "order_mode" => "nope", "recipients" => [ rina ], "total_charge" => "1.00" }
    ).call
    assert_error unknown, "UNKNOWN_FIELD", 422

    foreign = Envelopes::ChargePreview.new(
      envelope_id: "env_other",
      payload: { "order_mode" => "nope", "recipients" => [ rina ] }
    ).call
    assert_error foreign, "ENVELOPE_NOT_FOUND", 404

    mode = preview("order_mode" => "nope", "recipients" => [ rina.merge("email" => "not-an-email") ])
    assert_error mode, "ORDER_MODE_INVALID", 422
  end

  test "field geometry is rejected rather than clamped" do
    recipients = [ rina.merge("signature_count" => 1, "meterai_count" => 0) ]

    too_far = preview(
      "order_mode" => "parallel",
      "recipients" => recipients,
      "fields" => [ { "id" => "f1", "kind" => "signature", "recipient_email" => rina["email"], "page" => 1, "x" => 421, "y" => 0 } ]
    )
    assert_error too_far, "FIELD_OUT_OF_BOUNDS", 422

    meterai_too_far = preview(
      "order_mode" => "parallel",
      "recipients" => [ rina.merge("signature_count" => 1, "meterai_count" => 1) ],
      "fields" => [
        { "id" => "f1", "kind" => "signature", "recipient_email" => rina["email"], "page" => 1, "x" => 0, "y" => 0 },
        { "id" => "f2", "kind" => "meterai", "recipient_email" => rina["email"], "page" => 1, "x" => 0, "y" => 477 }
      ]
    )
    assert_error meterai_too_far, "FIELD_OUT_OF_BOUNDS", 422
  end

  test "field page, ids, unknown recipient, and count mismatch" do
    recipients = [ rina.merge("signature_count" => 1, "meterai_count" => 0) ]

    page = preview(
      "order_mode" => "parallel",
      "recipients" => recipients,
      "fields" => [ { "id" => "f1", "kind" => "signature", "recipient_email" => rina["email"], "page" => 2, "x" => 0, "y" => 0 } ]
    )
    assert_error page, "FIELD_PAGE_INVALID", 422

    duplicate = preview(
      "order_mode" => "parallel",
      "recipients" => recipients,
      "fields" => [
        { "id" => "f1", "kind" => "signature", "recipient_email" => rina["email"], "page" => 1, "x" => 0, "y" => 0 },
        { "id" => "f1", "kind" => "signature", "recipient_email" => rina["email"], "page" => 1, "x" => 0, "y" => 90 }
      ]
    )
    assert_error duplicate, "FIELD_ID_DUPLICATE", 422

    unknown = preview(
      "order_mode" => "parallel",
      "recipients" => recipients,
      "fields" => [ { "id" => "f1", "kind" => "signature", "recipient_email" => "other@example.test", "page" => 1, "x" => 0, "y" => 0 } ]
    )
    assert_error unknown, "FIELD_UNKNOWN_RECIPIENT", 422

    mismatch = preview(
      "order_mode" => "parallel",
      "recipients" => recipients,
      "fields" => []
    )
    assert_error mismatch, "FIELD_COUNT_MISMATCH", 422
  end

  test "several recipients may share a step and sign in parallel" do
    recipients = [
      rina.merge("step" => 1, "meterai_count" => 0),
      { "name" => "Citra Putri", "email" => "citra.putri@example.test", "signature_count" => 1, "meterai_count" => 0, "step" => 1 },
      { "name" => "Budi Santoso", "email" => "budi.santoso@example.test", "signature_count" => 1, "meterai_count" => 0, "step" => 2 }
    ]

    result = preview("order_mode" => "sequential", "recipients" => recipients)

    assert result.ok?
    assert_equal [
      { step: 1, recipient_emails: [ "rina.halim@example.test", "citra.putri@example.test" ] },
      { step: 2, recipient_emails: [ "budi.santoso@example.test" ] }
    ], result.value[:steps]
  end

  test "step sequence must start at 1 without gaps" do
    result = preview(
      "order_mode" => "sequential",
      "recipients" => [
        rina.merge("step" => 1, "meterai_count" => 0),
        { "name" => "Budi Santoso", "email" => "budi.santoso@example.test", "signature_count" => 1, "meterai_count" => 0, "step" => 3 }
      ]
    )

    assert_error result, "STEP_SEQUENCE_INVALID", 422
  end

  test "field-vs-count runs after meterai placement, so a late stamp is not a field error" do
    result = preview(
      "order_mode" => "sequential",
      "recipients" => [
        rina.merge("signature_count" => 1, "meterai_count" => 0, "step" => 1),
        { "name" => "Budi Santoso", "email" => "budi.santoso@example.test", "signature_count" => 1, "meterai_count" => 1, "step" => 2 }
      ],
      "fields" => []
    )

    assert_error result, "METERAI_NOT_IN_FIRST_STEP", 422
  end

  private

  def rina
    { "name" => "Rina Halim", "email" => "rina.halim@example.test", "signature_count" => 1, "meterai_count" => 0 }
  end

  def preview(payload)
    Envelopes::ChargePreview.new(envelope_id: @envelope_id, payload: payload).call
  end

  def assert_error(result, code, status)
    assert_not result.ok?, "expected #{code} but succeeded: #{result.value.inspect}"
    assert_equal code, result.error[:code]
    assert_equal status, result.http_status
  end
end
