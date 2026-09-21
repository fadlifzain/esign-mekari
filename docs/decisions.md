# Decisions

- Storage is process-local memory. Reviewers can run without a database of envelopes.
- Money is integer cents. Signature `"5000.00"` = 500000, meterai `"10000.25"` = 1000025.
- Max upload is 10 MB, enforced in `Envelopes::Create`, not only the browser.
- Filenames longer than 200 characters are truncated, keeping the extension.
- `fields` may be omitted from charge-preview (recipients page). When present, the server rejects out-of-range coordinates instead of clamping.
- P4 (`preview_token`, lock) is not implemented.
