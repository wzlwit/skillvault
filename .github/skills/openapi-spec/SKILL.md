---
name: openapi-spec
description: Design and validate REST API contracts. Use for /openapi-spec, legacy /openapi-spec-generation, OpenAPI or Swagger specifications, code-first API documentation, request and response schemas, contract drift, or SDK input specifications.
metadata:
  author: Seth Hobson
  maintainer: wzlwit
  version: null
---

# OpenAPI Specification Generation

Adapted from Seth Hobson's OpenAPI spec generation skill (`https://github.com/wshobson/agents`,
`plugins/documentation-generation/skills/openapi-spec-generation`, named `openapi-spec-generation`
there), MIT; see `UPSTREAM-LICENSE`. The original and its templates are in the Original section
below. Where it differs, the SkillVault rules above it win; for example, use the project's existing
tools instead of installing the linters and generators in its examples.

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

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.

## Original

<!-- upstream:begin -->
<!-- Original: https://github.com/wshobson/agents plugins/documentation-generation/skills/openapi-spec-generation at 156b7a5e7a8b93642628a339ee4039c925b34c7f. Refresh replaces this section; put SkillVault changes outside it. -->

# OpenAPI Spec Generation

Comprehensive patterns for creating, maintaining, and validating OpenAPI 3.1 specifications for RESTful APIs.

## When to Use This Skill

- Creating API documentation from scratch
- Generating OpenAPI specs from existing code
- Designing API contracts (design-first approach)
- Validating API implementations against specs
- Generating client SDKs from specs
- Setting up API documentation portals

## Core Concepts

### 1. OpenAPI 3.1 Structure

```yaml
openapi: 3.1.0
info:
  title: API Title
  version: 1.0.0
servers:
  - url: https://api.example.com/v1
paths:
  /resources:
    get: ...
components:
  schemas: ...
  securitySchemes: ...
```

### 2. Design Approaches

| Approach         | Description                  | Best For            |
| ---------------- | ---------------------------- | ------------------- |
| **Design-First** | Write spec before code       | New APIs, contracts |
| **Code-First**   | Generate spec from code      | Existing APIs       |
| **Hybrid**       | Annotate code, generate spec | Evolving APIs       |

## Templates and detailed worked examples

Full template library and detailed worked examples live in `references/details.md`. Read that file when you need the concrete templates.

## Best Practices

### Do's

- **Use $ref** - Reuse schemas, parameters, responses
- **Add examples** - Real-world values help consumers
- **Document errors** - All possible error codes
- **Version your API** - In URL or header
- **Use semantic versioning** - For spec changes

### Don'ts

- **Don't use generic descriptions** - Be specific
- **Don't skip security** - Define all schemes
- **Don't forget nullable** - Be explicit about null
- **Don't mix styles** - Consistent naming throughout
- **Don't hardcode URLs** - Use server variables
<!-- upstream:end -->
