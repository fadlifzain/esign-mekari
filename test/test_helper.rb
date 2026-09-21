ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module EnvelopeTestHelper
  def upload_envelope(filename: "agreement-vendor-2026.pdf", content: nil)
    tempfile = Tempfile.new([ "doc", File.extname(filename).presence || ".pdf" ])
    tempfile.binmode
    tempfile.write(content || pdf_bytes)
    tempfile.rewind
    file = Rack::Test::UploadedFile.new(tempfile.path, "application/pdf")
    file.define_singleton_method(:original_filename) { filename }

    result = Envelopes::Create.new(file: file).call
    raise result.error.fetch(:message) unless result.ok?

    result.value[:envelope_id]
  ensure
    tempfile&.close!
  end

  def pdf_bytes
    "%PDF-1.1\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n"
  end

  def fields_for(recipients)
    cursor_y = 0
    index = 0
    recipients.flat_map do |recipient|
      email = recipient[:email] || recipient["email"]
      signatures = recipient[:signature_count] || recipient["signature_count"]
      meterai = recipient[:meterai_count] || recipient["meterai_count"] || 0
      signature_fields = signatures.times.map do |offset|
        index += 1
        { "id" => "f#{index}", "kind" => "signature", "recipient_email" => email, "page" => 1, "x" => 0, "y" => cursor_y + (offset * 90) }
      end
      meterai_fields = meterai.times.map do |offset|
        index += 1
        { "id" => "f#{index}", "kind" => "meterai", "recipient_email" => email, "page" => 1, "x" => 360, "y" => cursor_y + (offset * 120) }
      end
      cursor_y += 200
      signature_fields + meterai_fields
    end
  end
end

module ActiveSupport
  class TestCase
    include EnvelopeTestHelper

    parallelize(workers: :number_of_processors)

    setup do
      EnvelopeStore.reset!
    end
  end
end
