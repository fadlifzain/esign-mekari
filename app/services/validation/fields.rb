module Validation
  module Fields
    module_function

    def bounds_for(kind)
      size = SignConfig::FIELD_SIZES[kind]
      return nil unless size

      {
        min_x: 0,
        max_x: SignConfig::CONTENT_WIDTH - size[:width],
        min_y: 0,
        max_y: SignConfig::CONTENT_HEIGHT - size[:height]
      }
    end

    def in_bounds?(kind, x, y)
      bounds = bounds_for(kind)
      return false unless bounds
      return false unless x.is_a?(Integer) && y.is_a?(Integer)

      x.between?(bounds[:min_x], bounds[:max_x]) && y.between?(bounds[:min_y], bounds[:max_y])
    end

    def clamp(kind, x, y)
      bounds = bounds_for(kind)
      return { x: 0, y: 0 } unless bounds

      xi = x.is_a?(Integer) ? x : 0
      yi = y.is_a?(Integer) ? y : 0
      {
        x: xi.clamp(bounds[:min_x], bounds[:max_x]),
        y: yi.clamp(bounds[:min_y], bounds[:max_y])
      }
    end
  end
end
