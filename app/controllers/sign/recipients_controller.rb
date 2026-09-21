module Sign
  class RecipientsController < BaseController
    def show
      @envelope_id = session[:envelope_id]
      @signature_price_cents = SignConfig::SIGNATURE_PRICE_CENTS
      @meterai_price_cents = SignConfig::METERAI_PRICE_CENTS
      @signature_quota = SignConfig::SIGNATURE_QUOTA
      @meterai_quota = SignConfig::METERAI_QUOTA
      @signers = [
        { name: "", email: "", signature_count: 1, meterai_count: 0, step: 1 }
      ]
    end
  end
end
