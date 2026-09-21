# Verification

```
$ bin/rails test
47 runs, 251 assertions, 0 failures, 0 errors, 0 skips
```

Manual check on `/sign/ws-a/recipients`: eMeterai stepper updates row charge (`Rp20.000,25`) and summary lines; sequential mode marks a step-2 stamp carrier on that row.

Covered: integer-cent charges including `"10000.25"` / `"25000.25"`, separate signature vs eMeterai quotas, sequential meterai only in step 1, parallel ignoring that rule, field bounds `[0,420]×[0,500]` / `[0,520]×[0,476]`, API 422 vs UI clamp, and the recipients page markup for the eMeterai column.

Node is not installed on this machine, so `test/javascript/sign_rules.test.mjs` was not executed. The same clamp/totals rules are asserted in the Rails validation tests.
