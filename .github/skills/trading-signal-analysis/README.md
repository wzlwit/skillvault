# Trading Signal Analysis

A research workflow for evaluating historical trading ideas against a comparable baseline.
It separates signal detection from later outcomes, keeps paired denominators consistent,
and reports target-touch rates without confusing them with trading profits.

Original author: `wzlwit`. Verified against the author's remote source and its companion
metrics and report files. This curation removes project-specific names, module paths, and
environment commands; it does not include private repository links or market datasets.

The source declares no release version or redistribution license, so both manifest fields
are `null`. Do not infer a public license from this local catalog entry; obtain the owner's
licensing approval before publishing or redistributing the bundle.

Suggested scope: `project`. The bundle is useful in a financial-research project that already
has a valid evaluator and licensed historical data. It installs no data provider, trading
software, hooks, or runtime dependencies and never authorizes orders or trade advice.

```text
/trading-signal-analysis Evaluate this breakout rule on the saved snapshot with matched peers.
```