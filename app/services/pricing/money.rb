module Pricing
  class Money
    attr_reader :cents

    def initialize(cents)
      raise ArgumentError, "cents must be an Integer" unless cents.is_a?(Integer)

      @cents = cents
    end

    def self.from_cents(cents)
      new(cents)
    end

    def +(other)
      self.class.new(cents + other.cents)
    end

    def *(factor)
      raise ArgumentError, "factor must be an Integer" unless factor.is_a?(Integer)

      self.class.new(cents * factor)
    end

    def to_api
      sign = cents.negative? ? "-" : ""
      abs = cents.abs
      "#{sign}#{abs / 100}.#{format("%02d", abs % 100)}"
    end

    def to_display
      sign = cents.negative? ? "-" : ""
      abs = cents.abs
      whole = abs / 100
      fraction = format("%02d", abs % 100)
      grouped = whole.to_s.chars.reverse.each_slice(3).map(&:join).join(".").reverse
      "#{sign}Rp#{grouped},#{fraction}"
    end

    def ==(other)
      other.is_a?(self.class) && other.cents == cents
    end
  end
end
