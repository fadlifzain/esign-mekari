require "test_helper"

class Pricing::MoneyTest < ActiveSupport::TestCase
  test "formats API money with exactly two fraction digits" do
    assert_equal "5000.00", Pricing::Money.from_cents(SignConfig::SIGNATURE_PRICE_CENTS).to_api
    assert_equal "10000.25", Pricing::Money.from_cents(SignConfig::METERAI_PRICE_CENTS).to_api
    assert_match(/\A\d+\.\d{2}\z/, Pricing::Money.from_cents(SignConfig::METERAI_PRICE_CENTS).to_api)
  end

  test "formats Indonesian display without binary floats" do
    assert_equal "Rp5.000,00", Pricing::Money.from_cents(SignConfig::SIGNATURE_PRICE_CENTS).to_display
    assert_equal "Rp10.000,25", Pricing::Money.from_cents(SignConfig::METERAI_PRICE_CENTS).to_display
  end

  test "multiplies by integer counts only" do
    stamp = Pricing::Money.from_cents(SignConfig::METERAI_PRICE_CENTS)
    assert_equal "20000.50", (stamp * 2).to_api
    assert_raises(ArgumentError) { stamp * 1.5 }
  end
end
