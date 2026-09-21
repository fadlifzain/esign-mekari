module SignConfig
  IDENTITY = "demo-a"
  WORKSPACE_ID = "ws-a"

  SIGNATURE_PRICE_CENTS = 500_000      # "5000.00"
  METERAI_PRICE_CENTS = 1_000_025      # "10000.25"
  SIGNATURE_QUOTA = 8
  METERAI_QUOTA = 3
  MAX_RECIPIENTS = 10
  SIGNATURE_MIN = 1
  SIGNATURE_MAX = 20
  METERAI_MIN = 0
  METERAI_MAX = 3
  MAX_FILENAME = 200
  MAX_FILE_BYTES = 10 * 1024 * 1024
  ALLOWED_EXTENSIONS = %w[pdf jpg jpeg png doc docx].freeze
  PAGE_COUNTS = {
    "agreement-vendor-2026.pdf" => 8,
    "nda-partner.pdf" => 3,
    "berita-acara.docx" => 1
  }.freeze

  CONTENT_WIDTH = 632
  CONTENT_HEIGHT = 588
  FIELD_SIZES = {
    "signature" => { width: 212, height: 88 }.freeze,
    "meterai" => { width: 112, height: 112 }.freeze
  }.freeze
end
