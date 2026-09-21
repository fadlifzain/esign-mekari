module Validation
  module Payload
    module_function

    def extra_keys(hash, allowed)
      hash.keys.map(&:to_s) - allowed.map(&:to_s)
    end
  end
end
