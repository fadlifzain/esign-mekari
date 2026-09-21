require "test_helper"

class Validation::FieldsTest < ActiveSupport::TestCase
  test "signature bounds match the content area minus field size" do
    bounds = Validation::Fields.bounds_for("signature")

    assert_equal 0, bounds[:min_x]
    assert_equal 420, bounds[:max_x]
    assert_equal 0, bounds[:min_y]
    assert_equal 500, bounds[:max_y]
    assert Validation::Fields.in_bounds?("signature", 0, 0)
    assert Validation::Fields.in_bounds?("signature", 420, 500)
    assert_not Validation::Fields.in_bounds?("signature", 421, 0)
    assert_not Validation::Fields.in_bounds?("signature", 0, 501)
  end

  test "meterai bounds match the content area minus field size" do
    bounds = Validation::Fields.bounds_for("meterai")

    assert_equal 0, bounds[:min_x]
    assert_equal 520, bounds[:max_x]
    assert_equal 0, bounds[:min_y]
    assert_equal 476, bounds[:max_y]
    assert Validation::Fields.in_bounds?("meterai", 520, 476)
    assert_not Validation::Fields.in_bounds?("meterai", 521, 0)
    assert_not Validation::Fields.in_bounds?("meterai", 0, 477)
  end

  test "non-integers are out of bounds so the API can reject them" do
    assert_not Validation::Fields.in_bounds?("signature", 64.0, 224)
    assert_not Validation::Fields.in_bounds?("signature", "64", 224)
  end

  test "UI clamp stays inside geometry while API still treats 421 as invalid" do
    assert_equal({ x: 420, y: 500 }, Validation::Fields.clamp("signature", 500, 800))
    assert_equal({ x: 0, y: 476 }, Validation::Fields.clamp("meterai", -10, 900))
    assert_not Validation::Fields.in_bounds?("signature", 421, 0)
    assert_not Validation::Fields.in_bounds?("meterai", 0, 477)
  end
end
