---
name: openapi-spec
description: Design and validate REST API contracts. Use for /openapi-spec, legacy /openapi-spec-generation, OpenAPI or Swagger specifications, code-first API documentation, request and response schemas, contract drift, or SDK input specifications.
metadata:
  author: Seth Hobson
  maintainer: wzlwit
  version: null
---

# OpenAPI Specification Generation

Keep the API contract aligned with either the current implementation or an explicitly
approved design. A plausible specification is not evidence that an endpoint implements it.

## Workflow

1. Read the existing specification, route handlers, serializers, authentication rules, and
   nearest contract tests. Identify the supported OpenAPI version and generation command.
2. For an existing API, derive the contract from its real behavior using the existing
   generator where possible. For design-first work, agree on operations and compatibility
   before changing implementation. Do not silently upgrade the specification version.
3. Describe path, query, and header parameters; request bodies; required and nullable fields;
   success and error responses; security schemes; and relevant pagination or limits. Preserve
   exact field names, enum values, status codes, and public operation IDs.
4. Reuse component schemas where they describe the same contract. Keep examples consistent
   with schemas and use synthetic values. Distinguish proposed endpoints from verified ones.
5. Run the project's OpenAPI validator or linter, including reference resolution. Compare
   changed operations with callers and existing contract tests for breaking changes. Syntax
   validation alone does not establish implementation compliance.
6. Report changed operations, validation results, compatibility impact, and any unverified
   implementation behavior. Generate SDKs or publish documentation only when requested.

## Boundaries

- Reuse repository tooling; do not introduce a generator, SDK, or documentation server just
  to produce a specification. Missing tooling is a setup requirement to disclose.
- Do not put tokens, private URLs, production payloads, or customer data into examples.
- Do not call production write endpoints to discover their contracts. Use approved local
  fixtures or test environments and add only meaningful coverage for changed behavior.

## Source and Curation

Curated SkillVault guide for Seth Hobson's
[OpenAPI skill in wshobson/agents](https://github.com/wshobson/agents/tree/main/plugins/documentation-generation/skills/openapi-spec-generation),
which is [MIT licensed](https://github.com/wshobson/agents/blob/main/LICENSE).
Authorship stays with Seth Hobson; wzlwit maintains this curated guide. The wording is
rephrased for SkillVault and is not the unchanged upstream skill. Its template library
remains upstream and is not bundled. This guide declares no version because it does not
track an upstream release.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.
