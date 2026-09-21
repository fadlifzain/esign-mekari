module Envelopes
  class Create
    def initialize(file:, extra_keys: [], workspace_id: Current.workspace_id, store: EnvelopeStore.instance)
      @file = file
      @extra_keys = extra_keys
      @workspace_id = workspace_id
      @store = store
    end

    def call
      extra = Array(@extra_keys).map(&:to_s) - %w[file authenticity_token]
      return unknown_field(extra.first) if extra.any?
      return error("FILE_REQUIRED", "A document file is required") if @file.blank?

      original_name = @file.respond_to?(:original_filename) ? @file.original_filename : nil
      filename = Validation::Filename.sanitize(original_name)
      return error("FILENAME_INVALID", "The filename is not valid") if filename.blank?
      return error("FILE_TYPE_NOT_ALLOWED", "File type is not supported") unless Validation::Filename.allowed?(filename)

      size_bytes = @file.respond_to?(:size) ? @file.size.to_i : 0
      if size_bytes > SignConfig::MAX_FILE_BYTES
        return error("FILE_TOO_LARGE", "File must be #{SignConfig::MAX_FILE_BYTES / 1.megabyte} MB or smaller")
      end

      envelope = @store.create(
        workspace_id: @workspace_id,
        filename: filename,
        size_bytes: size_bytes,
        page_count: Validation::Filename.page_count(filename)
      )

      ServiceResult.created(
        envelope_id: envelope.id,
        document: {
          filename: envelope.filename,
          size_bytes: envelope.size_bytes,
          page_count: envelope.page_count
        },
        price: {
          signature: Pricing::Money.from_cents(SignConfig::SIGNATURE_PRICE_CENTS).to_api,
          meterai: Pricing::Money.from_cents(SignConfig::METERAI_PRICE_CENTS).to_api
        },
        quota: {
          signature: SignConfig::SIGNATURE_QUOTA,
          meterai: SignConfig::METERAI_QUOTA
        }
      )
    end

    private

    def unknown_field(key)
      error("UNKNOWN_FIELD", "Unknown field #{key}")
    end

    def error(code, message)
      ServiceResult.error(code: code, message: message)
    end
  end
end
