module Sign
  class RecipientsController < BaseController
    def show
      @price_per_signature = 5_000
      @signers = [
        { name: "", email: "", count: 1 }
      ]
    end
  end
end
