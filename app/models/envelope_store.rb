class EnvelopeStore
  Envelope = Struct.new(:id, :workspace_id, :filename, :size_bytes, :page_count, keyword_init: true)

  class << self
    def instance
      @instance ||= new
    end

    def reset!
      instance.reset!
      seed_foreign!
      instance
    end

    def seed_foreign!
      instance.insert(
        Envelope.new(
          id: "env_other",
          workspace_id: "ws-b",
          filename: "other.pdf",
          size_bytes: 10,
          page_count: 1
        )
      )
    end

    delegate :create, :insert, :find, to: :instance
  end

  def initialize
    @mutex = Mutex.new
    reset!
  end

  def reset!
    @mutex.synchronize do
      @records = {}
      @counter = 0
    end
  end

  def create(attrs)
    @mutex.synchronize do
      @counter += 1
      id = "env_#{@counter.to_s.rjust(2, "0")}"
      record = Envelope.new(**attrs, id: id)
      @records[id] = record
      record
    end
  end

  def insert(envelope)
    @mutex.synchronize { @records[envelope.id] = envelope }
  end

  def find(id)
    @mutex.synchronize { @records[id] }
  end
end
