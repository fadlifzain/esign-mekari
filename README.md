# Esign Mekari (interview simulation)

```
bin/setup
bin/rails server
bin/rails test
node --test test/javascript/sign_rules.test.mjs
```

App: `http://localhost:3000/sign/ws-a` (HTML). APIs: `POST /api/envelopes`, `POST /api/envelopes/:id/charge-preview`.

Identity `demo-a` is mapped server-side to workspace `ws-a`. A `workspace_id` from the client is not authorization. Envelopes are in-memory; SQL injection is not applicable, input is still validated.
