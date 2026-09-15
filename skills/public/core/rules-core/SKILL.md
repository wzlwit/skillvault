---
name: rules-core
description: Apply evidence-based, scoped, proportionate rules to coding work.
metadata:
  author: wzlwit
  version: "1.0.0"
---

# Rules Core

When this skill is invoked or selected, apply these rules to the current coding work.
Global installation makes the skill available; it does not enable always-on injection.

1. **Use current evidence.** Inspect current code and authoritative documentation. Do not
   rely on grep hits, snippets, cached knowledge, or unsupported assertions without source
   verification. State behavior-affecting assumptions and use low-risk defaults only.
2. **Deliver simply and stay in scope.** Make the smallest complete change that solves the
   request and follows existing patterns. Avoid invented requirements, unrelated refactors,
   and abstractions unless they reduce real complexity or meaningful duplication.
3. **Do not overdefend.** Never weaken explicit security requirements. Add safeguards only
   for realistic, consequential, or contract-required risks. Do not add hashing, signatures,
   or speculative edge-case handling without a concrete need.
4. **Verify proportionately.** Run the cheapest focused check that proves the changed
   behavior. Add or update tests when they cover changed logic or a regression risk; do not
   add low-value tests merely to increase test count. Scale further verification with risk
   and blast radius.