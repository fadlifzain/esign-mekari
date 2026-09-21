module Validation
  module Filename
    module_function

    def sanitize(name)
      return "" if name.nil?

      basename = name.to_s.tr("\\", "/").split("/").last.to_s.delete("\0").strip
      return "" if basename.blank? || basename == "." || basename == ".."

      if basename.length > SignConfig::MAX_FILENAME
        extension = File.extname(basename)
        stem = File.basename(basename, extension)
        keep = SignConfig::MAX_FILENAME - extension.length
        keep = 1 if keep < 1
        basename = "#{stem.byteslice(0, keep)}#{extension}"
        basename = basename.byteslice(0, SignConfig::MAX_FILENAME)
      end

      basename
    end

    def extension(sanitized)
      File.extname(sanitized.to_s).delete_prefix(".").downcase
    end

    def allowed?(sanitized)
      SignConfig::ALLOWED_EXTENSIONS.include?(extension(sanitized))
    end

    def page_count(sanitized)
      SignConfig::PAGE_COUNTS.fetch(sanitized.to_s.downcase, 1)
    end
  end
end
