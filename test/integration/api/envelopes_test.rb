require "test_helper"

class Api::EnvelopesTest < ActionDispatch::IntegrationTest
  test "upload of the vendor PDF returns 201 with 8 pages" do
    post api_envelopes_url, params: { file: uploaded("agreement-vendor-2026.pdf") }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "agreement-vendor-2026.pdf", body.dig("document", "filename")
    assert_equal 8, body.dig("document", "page_count")
    assert_equal "5000.00", body.dig("price", "signature")
    assert_equal "10000.25", body.dig("price", "meterai")
    assert_equal 8, body.dig("quota", "signature")
    assert_equal 3, body.dig("quota", "meterai")
  end

  test "exe and pdf.exe are rejected with FILE_TYPE_NOT_ALLOWED" do
    post api_envelopes_url, params: { file: uploaded("payload.exe") }
    assert_response :unprocessable_entity
    assert_equal "FILE_TYPE_NOT_ALLOWED", JSON.parse(response.body).dig("error", "code")

    post api_envelopes_url, params: { file: uploaded("evil.pdf.exe") }
    assert_response :unprocessable_entity
    assert_equal "FILE_TYPE_NOT_ALLOWED", JSON.parse(response.body).dig("error", "code")
  end

  test "path traversal filenames are stored as a basename" do
    post api_envelopes_url, params: { file: uploaded("../../etc/passwd.pdf") }

    assert_response :created
    assert_equal "passwd.pdf", JSON.parse(response.body).dig("document", "filename")
  end

  test "XSS filenames are returned as text" do
    post api_envelopes_url, params: { file: uploaded("<img src=x onerror=alert(1)>.pdf") }

    assert_response :created
    filename = JSON.parse(response.body).dig("document", "filename")
    assert_equal "<img src=x onerror=alert(1)>.pdf", filename
    assert_no_match(/<script/i, response.body)
  end

  test "files over 10 MB are rejected on the server" do
    oversized = Struct.new(:original_filename, :size).new("agreement-vendor-2026.pdf", 11 * 1024 * 1024)
    result = Envelopes::Create.new(file: oversized).call

    assert_equal "FILE_TOO_LARGE", result.error[:code]
  end

  test "charge-preview HTTP contract for sequential meterai" do
    envelope_id = upload_via_http
    recipients = [
      { name: "Rina Halim", email: "rina.halim@example.test", signature_count: 2, meterai_count: 1, step: 1 },
      { name: "Budi Santoso", email: "budi.santoso@example.test", signature_count: 1, meterai_count: 0, step: 2 }
    ]

    post charge_preview_api_envelope_url(envelope_id),
      params: {
        order_mode: "sequential",
        recipients: recipients,
        fields: [
          { id: "f1", kind: "signature", recipient_email: "rina.halim@example.test", page: 1, x: 64, y: 224 },
          { id: "f2", kind: "signature", recipient_email: "rina.halim@example.test", page: 1, x: 64, y: 340 },
          { id: "f3", kind: "meterai", recipient_email: "rina.halim@example.test", page: 1, x: 360, y: 224 },
          { id: "f4", kind: "signature", recipient_email: "budi.santoso@example.test", page: 1, x: 64, y: 440 }
        ]
      },
      as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 3, body["total_signatures"]
    assert_equal 1, body["total_meterai"]
    assert_equal "25000.25", body["total_charge"]
    assert_equal({ "signature" => 6, "meterai" => 2 }, body["quota_remaining"])
  end

  test "client totals and workspace ids are never accepted" do
    envelope_id = upload_via_http

    post charge_preview_api_envelope_url(envelope_id),
      params: {
        order_mode: "parallel",
        recipients: [ { name: "Rina Halim", email: "rina.halim@example.test", signature_count: 1 } ],
        total_charge: "1.00",
        workspace_id: "ws-b"
      },
      as: :json

    assert_response :unprocessable_entity
    assert_equal "UNKNOWN_FIELD", JSON.parse(response.body).dig("error", "code")
  end

  test "foreign and missing envelopes return identical 404 JSON" do
    payload = { order_mode: "parallel", recipients: [ { name: "Rina Halim", email: "rina.halim@example.test", signature_count: 1 } ] }

    post charge_preview_api_envelope_url("missing"), params: payload, as: :json
    missing = response.body
    assert_response :not_found

    post charge_preview_api_envelope_url("env_other"), params: payload, as: :json
    assert_response :not_found
    assert_equal missing, response.body
  end

  test "forced quota overflow is 422 with the matching product code" do
    envelope_id = upload_via_http

    post charge_preview_api_envelope_url(envelope_id),
      params: {
        order_mode: "parallel",
        recipients: (1..9).map { |index|
          { name: "Signer #{index}", email: "signer#{index}@example.test", signature_count: 1 }
        }
      },
      as: :json
    assert_equal "INSUFFICIENT_SIGNATURE_QUOTA", JSON.parse(response.body).dig("error", "code")

    post charge_preview_api_envelope_url(envelope_id),
      params: {
        order_mode: "parallel",
        recipients: [
          { name: "Rina Halim", email: "rina.halim@example.test", signature_count: 3, meterai_count: 3 },
          { name: "Budi Santoso", email: "budi.santoso@example.test", signature_count: 1, meterai_count: 1 }
        ]
      },
      as: :json
    assert_equal "INSUFFICIENT_METERAI_QUOTA", JSON.parse(response.body).dig("error", "code")
  end

  private

  def uploaded(filename)
    tempfile = Tempfile.new([ "upload", File.extname(filename).presence || ".bin" ])
    tempfile.binmode
    tempfile.write(pdf_bytes)
    tempfile.rewind
    Rack::Test::UploadedFile.new(tempfile.path, "application/octet-stream").tap do |file|
      file.define_singleton_method(:original_filename) { filename }
    end
  end

  def upload_via_http
    post api_envelopes_url, params: { file: uploaded("agreement-vendor-2026.pdf") }
    JSON.parse(response.body).fetch("envelope_id")
  end
end
