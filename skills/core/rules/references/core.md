
# Rules Core

For `/rules apply`, apply these rules to the current coding work without editing rule files.
Global installation makes the guide available; it does not enable always-on injection.

1. **Use current evidence.** Inspect current code and authoritative documentation. Do not
   rely on grep hits, snippets, cached knowledge, or unsupported assertions without source
   verification. Honor an explicit evidence target first; otherwise search local, configured
   accessible internal, then external sources only as needed, preferring official sources.
   Do not send private details to public searches or substitute for an unavailable explicit target.
   State behavior-affecting assumptions and use low-risk defaults only.
2. **Deliver simply and stay in scope.** Make the smallest complete change that solves the
   request and follows existing patterns. Avoid invented requirements, unrelated refactors,
   and abstractions unless they reduce real complexity or meaningful duplication.
3. **Do not overdefend.** Preserve explicit security requirements, user constraints, and
   permission boundaries. Add safeguards, restrictions, resource caps, or extra approval gates
   only for a concrete need. Address realistic, consequential, or contract-required risks,
   not speculative edge cases.
4. **Verify proportionately.** Run the cheapest focused check that proves the changed
   behavior. Add or update tests to protect changed logic or prevent regressions, not merely
   to increase test count. Scale verification with risk and blast radius.

Read the [centrally maintained detailed reference](ai-principles.md) only when clarification is needed.