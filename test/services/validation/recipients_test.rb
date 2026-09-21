require "test_helper"

class Validation::RecipientsTest < ActiveSupport::TestCase
  test "rejects empty names" do
    assert_not Validation::Recipients.valid_name?("")
    assert_not Validation::Recipients.valid_name?("   ")
    assert Validation::Recipients.valid_name?("Rina Halim")
  end

  test "email rule is trim, one at-sign, dotted domain" do
    assert Validation::Recipients.valid_email?("rina.halim@example.test")
    assert Validation::Recipients.valid_email?("  rina@example.test ")
    assert_not Validation::Recipients.valid_email?("rina.example.test")
    assert_not Validation::Recipients.valid_email?("rina@example")
    assert_not Validation::Recipients.valid_email?("rina@@example.test")
    assert_not Validation::Recipients.valid_email?("@example.test")
  end

  test "duplicate emails are compared after trim, case-insensitively" do
    assert Validation::Recipients.duplicate_emails?([ "  Rina.Halim@Example.test ", "rina.halim@example.test" ])
    assert_not Validation::Recipients.duplicate_emails?([ "rina.halim@example.test", "budi.santoso@example.test" ])
  end

  test "each recipient may have 1 to 20 signatures independent of quota rows" do
    assert Validation::Recipients.integer_in?(1, SignConfig::SIGNATURE_MIN, SignConfig::SIGNATURE_MAX)
    assert Validation::Recipients.integer_in?(20, SignConfig::SIGNATURE_MIN, SignConfig::SIGNATURE_MAX)
    assert_not Validation::Recipients.integer_in?(0, SignConfig::SIGNATURE_MIN, SignConfig::SIGNATURE_MAX)
    assert_not Validation::Recipients.integer_in?(-1, SignConfig::SIGNATURE_MIN, SignConfig::SIGNATURE_MAX)
    assert_not Validation::Recipients.integer_in?(2.5, SignConfig::SIGNATURE_MIN, SignConfig::SIGNATURE_MAX)
    assert_not Validation::Recipients.integer_in?("2", SignConfig::SIGNATURE_MIN, SignConfig::SIGNATURE_MAX)
    assert_equal 1, SignConfig::SIGNATURE_MIN
    assert_equal 20, SignConfig::SIGNATURE_MAX
    assert_equal 8, SignConfig::SIGNATURE_QUOTA
    assert Validation::Recipients.integer_in?(0, 0, 3)
    assert Validation::Recipients.integer_in?(3, 0, 3)
    assert_not Validation::Recipients.integer_in?(4, 0, 3)
  end

  test "sequential steps start at 1 and do not skip" do
    assert Validation::Recipients.consecutive_steps?([ 1, 2 ])
    assert Validation::Recipients.consecutive_steps?([ 1, 1, 2 ])
    assert_not Validation::Recipients.consecutive_steps?([ 1, 3 ])
    assert_not Validation::Recipients.consecutive_steps?([ 2, 3 ])
  end

  test "UI clamps signature and meterai counts without NaN" do
    assert_equal 1, Validation::Recipients.clamp_signature_count("abc")
    assert_equal 1, Validation::Recipients.clamp_signature_count(0)
    assert_equal 1, Validation::Recipients.clamp_signature_count(-1)
    assert_equal 20, Validation::Recipients.clamp_signature_count(21)
    assert_equal 0, Validation::Recipients.clamp_meterai_count("abc", 2)
    assert_equal 0, Validation::Recipients.clamp_meterai_count(-1, 2)
    assert_equal 2, Validation::Recipients.clamp_meterai_count(4, 2)
    assert_equal 1, Validation::Recipients.clamp_meterai_count(3, 1)
    assert_equal 3, Validation::Recipients.clamp_meterai_count(3, 20)
  end
end
