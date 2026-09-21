module Pricing
  class Calculator
    def self.totals(recipients)
      total_signatures = recipients.sum { |recipient| recipient[:signature_count].to_i }
      total_meterai = recipients.sum { |recipient| recipient[:meterai_count].to_i }
      signature_charge = Pricing::Money.from_cents(SignConfig::SIGNATURE_PRICE_CENTS * total_signatures)
      meterai_charge = Pricing::Money.from_cents(SignConfig::METERAI_PRICE_CENTS * total_meterai)

      {
        total_signatures: total_signatures,
        total_meterai: total_meterai,
        signature_charge: signature_charge,
        meterai_charge: meterai_charge,
        total_charge: signature_charge + meterai_charge,
        quota_remaining: {
          signature: SignConfig::SIGNATURE_QUOTA - recipients.size,
          meterai: SignConfig::METERAI_QUOTA - total_meterai
        }
      }
    end

    def self.recipient_charge(recipient)
      signature = Pricing::Money.from_cents(SignConfig::SIGNATURE_PRICE_CENTS * recipient[:signature_count].to_i)
      meterai = Pricing::Money.from_cents(SignConfig::METERAI_PRICE_CENTS * recipient[:meterai_count].to_i)
      signature + meterai
    end
  end
end
