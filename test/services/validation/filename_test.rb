require "test_helper"

class Validation::FilenameTest < ActiveSupport::TestCase
  test "strips path components before storing" do
    assert_equal "passwd.pdf", Validation::Filename.sanitize("../../etc/passwd.pdf")
    assert_equal "nda-partner.pdf", Validation::Filename.sanitize("C:\\windows\\nda-partner.pdf")
  end

  test "keeps an XSS filename as a basename string" do
    assert_equal "<img src=x onerror=alert(1)>.pdf", Validation::Filename.sanitize("<img src=x onerror=alert(1)>.pdf")
  end

  test "rejects disallowed extensions from the sanitized name" do
    assert_not Validation::Filename.allowed?(Validation::Filename.sanitize("payload.exe"))
    assert_not Validation::Filename.allowed?(Validation::Filename.sanitize("evil.pdf.exe"))
    assert Validation::Filename.allowed?(Validation::Filename.sanitize("agreement-vendor-2026.pdf"))
  end

  test "page counts come from the fixture table" do
    assert_equal 8, Validation::Filename.page_count("agreement-vendor-2026.pdf")
    assert_equal 3, Validation::Filename.page_count("NDA-PARTNER.PDF")
    assert_equal 1, Validation::Filename.page_count("other.docx")
  end

  test "empty or dot names are invalid" do
    assert_equal "", Validation::Filename.sanitize("")
    assert_equal "", Validation::Filename.sanitize("..")
    assert_equal "", Validation::Filename.sanitize("/")
  end
end
