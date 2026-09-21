class ServiceResult
  attr_reader :value, :error, :http_status

  def initialize(ok:, value: nil, error: nil, http_status:)
    @ok = ok
    @value = value
    @error = error
    @http_status = http_status
  end

  def self.ok(value, http_status: 200)
    new(ok: true, value: value, http_status: http_status)
  end

  def self.created(value)
    ok(value, http_status: 201)
  end

  def self.error(code:, message:, http_status: 422, **extra)
    new(ok: false, error: { code: code, message: message }.merge(extra), http_status: http_status)
  end

  def ok?
    @ok
  end
end
