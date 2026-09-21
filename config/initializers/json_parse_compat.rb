# json 3.x only accepts keyword options. ActiveSupport still calls
# JSON.parse(json, options) with a positional Hash (e.g. when reading the session).
module JsonParsePositionalOptions
  def parse(source, opts = nil, **kwargs)
    kwargs = opts.merge(kwargs) if opts.is_a?(Hash)
    super(source, **kwargs)
  end
end

JSON.singleton_class.prepend(JsonParsePositionalOptions)
