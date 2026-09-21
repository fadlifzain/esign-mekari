require "test_helper"

class Pricing::CalculatorTest < ActiveSupport::TestCase
  test "Rina 2 + Budi 1 signatures charge and remaining quota" do
    totals = Pricing::Calculator.totals([
      { signature_count: 2, meterai_count: 0 },
      { signature_count: 1, meterai_count: 0 }
    ])

    assert_equal 3, totals[:total_signatures]
    assert_equal 0, totals[:total_meterai]
    assert_equal "15000.00", totals[:signature_charge].to_api
    assert_equal "0.00", totals[:meterai_charge].to_api
    assert_equal "15000.00", totals[:total_charge].to_api
    assert_equal 6, totals[:quota_remaining][:signature]
    assert_equal 3, totals[:quota_remaining][:meterai]
  end

  test "combined signature and meterai totals stay on integer cents" do
    totals = Pricing::Calculator.totals([
      { signature_count: 2, meterai_count: 1 },
      { signature_count: 1, meterai_count: 0 }
    ])

    assert_equal 3, totals[:total_signatures]
    assert_equal 1, totals[:total_meterai]
    assert_equal "15000.00", totals[:signature_charge].to_api
    assert_equal "10000.25", totals[:meterai_charge].to_api
    assert_equal "25000.25", totals[:total_charge].to_api
    assert_equal 6, totals[:quota_remaining][:signature]
    assert_equal 2, totals[:quota_remaining][:meterai]
  end

  test "signature quota remaining is recipient rows, not stamp count" do
    totals = Pricing::Calculator.totals([
      { signature_count: 20, meterai_count: 0 },
      { signature_count: 20, meterai_count: 0 }
    ])

    assert_equal 40, totals[:total_signatures]
    assert_equal 6, totals[:quota_remaining][:signature]
  end

  test "quota boundary of 8 recipient rows is remaining 0, not an error" do
    totals = Pricing::Calculator.totals(8.times.map { { signature_count: 2, meterai_count: 0 } })

    assert_equal 16, totals[:total_signatures]
    assert_equal 0, totals[:quota_remaining][:signature]
  end

  test "per-recipient charge combines both products" do
    charge = Pricing::Calculator.recipient_charge(signature_count: 2, meterai_count: 1)

    assert_equal "20000.25", charge.to_api
    assert_equal "Rp20.000,25", charge.to_display
  end
end
