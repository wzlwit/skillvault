---
name: trading-signal-analysis
description: Evaluate historical trading approaches, price patterns, or screenshots through signal-outcome studies. Use for historical backtesting, target-hit and endpoint-close rates, matched-peer benchmarks, percentage-point differences, and lookback, target, or follow-up sensitivity. Keep research distinct from profit claims and trade advice.
argument-hint: '<approach-or-source> [<market-or-universe>] [<lookbacks>] [<targets>] [<follow-up-sessions>]'
metadata:
  author: wzlwit
---

# Trading Signal Analysis

Turn a trading idea into a reproducible historical signal-outcome study. Reuse the project's
actual evaluator, data snapshot, exchange calendar, and report conventions. This skill is a
research workflow, not a trading engine, market-data source, or portfolio-profit simulator.

## Workflow

1. Read the original idea and the implementation that decides a signal. Define the market,
   universe and membership date, provider, price adjustment basis, cutoff, evaluator version,
   lookback, fresh-event rule, baseline, targets, follow-up sessions, and comparator. Label
   screenshot interpretations and missing thresholds as assumptions, not the author's rules.
2. Validate available data before downloading more: symbol identity, chronology, completed
   exchange sessions, warm-up history, OHLC consistency, corporate actions, gaps, and units.
   Verify market-specific limits and rounding from historical rules where relevant. Disclose
   survivorship bias when using today's constituents instead of point-in-time membership.
3. Replay signals using only inputs available at each signal date. Later prices and future
   data availability must not determine event identity or peer selection. Keep explicit event
   keys and retain detected events even if their follow-up is incomplete. Do not invent a
   non-ready state across missing history or merge legitimate repeated events.
4. Measure outcomes using [Metrics and Checks](./references/metrics-and-checks.md). For a
   signal-close baseline, follow-up starts at the next exchange session. Report intraday
   target-touch and final-session close separately, with numerators, evaluated denominators,
   censored counts, distinct stocks/dates, and exclusion reasons. Empty samples have no rate.
5. Define the benchmark before inspecting outcomes. Match peers using only information
   available at signal time, exclude the signal stock, and explain the comparator's filters.
   For a fixed-size paired design, keep only groups whose signal and all preselected peers
   have complete follow-up. Never replace a peer because its future is missing or unfavorable.
   Compare signal and peer rates on those same groups, with equal total weight per group.
6. For target-only changes, rescore verified saved outcomes without changing event identities,
   peers, horizons, or exclusions. For other sensitivity studies, state what changed and use
   a common sample where needed. Do not choose a validated winner from the best retrospective
   row or describe reused data as an untouched holdout.
7. Verify the consequential risks with focused checks from the reference. Independently
   recompute selected outcomes and aggregate counts; invoking the same evaluator twice is
   not an independent arithmetic check. Add tests only for changed logic or meaningful gaps.
8. Use the [report template](./assets/report-template.md), retaining actual event/peer tables,
   exclusions, effective settings, snapshot provenance, and replay commands. Preserve earlier
   runs. Report exact checks performed and any missing data or unverified statistical claims.

## Interpretation and Safety

- A target hit is a historical event frequency, not realized profit or a future probability.
  Use signed percentage-point differences, not return percentages. Account for repeated
  stocks, shared dates, and overlapping horizons before claiming statistical significance.
- Do not alter model defaults, supported ranges, positions, orders, or tracking records to
  run research. No trade execution or personalized investment recommendation is authorized.
- Use existing data and tooling. Get approval for paid data or a changed provider; never
  request secrets in chat, silently substitute synthetic data, or manufacture missing results.
- Keep raw data and confidential strategy details out of public reports. Respect provider
  redistribution terms. Publication and any trading action need separate authorization.
- This bundle supplies instructions, metric definitions, and a report template only. If the
  required evaluator, data, or permissions are absent, report the blocker without fabricating
  an analysis. Source version and redistribution license are undeclared; see [README](./README.md).

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.
