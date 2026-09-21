Rails.application.config.after_initialize do
  EnvelopeStore.reset!
end
