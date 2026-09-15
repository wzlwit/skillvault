# Metrics and Checks

## Outcome Definitions

For a percentage target and each stock's own signal-close baseline:

$$
\text{threshold} = \text{baseline}\left(1 + \frac{\text{target percent}}{100}\right)
$$

The observation interval is the next exchange session through the declared final session.
An intraday high at or above the threshold is a target touch; a final-session close at or
above it is an endpoint-close success. Equality counts. Declare exact-percentage versus
tick-rounded prices and use tested boundary arithmetic consistently.

Keep detected signals, evaluable signals, and censored signals distinct. Under a complete-window
policy, missing follow-up censors the event even if an earlier price already touched the target.
State that policy and its selection limitations; do not silently count missing data as failure.

$$
\text{Hit rate (\%)} = 100\frac{\text{hit count}}{\text{evaluated signals}}
$$

$$
\text{Endpoint-close rate (\%)} = 100\frac{\text{close count}}{\text{evaluated signals}}
$$

## Paired Comparison

Select controls using historical information before examining their outcomes. For a
fixed-size design, a paired group is valid only when the signal and every preselected
control are evaluable. Do not replace missing peers. Compute the signal rate on these
same paired groups, not on all independently evaluable signals.

$$
\text{Peer hit rate (\%)} = 100\frac{\text{peer hit count}}{\text{paired signals}\times\text{controls per signal}}
$$

$$
\text{Difference (pp)} = \text{paired signal rate (\%)} - \text{paired peer rate (\%)}
$$

Use the same subtraction for endpoint-close rates. Variable control counts need explicit
weights so each signal's peers have a total weight of one. Calculate differences from
unrounded rates and round for display only. Zero denominators produce null/not available.

Illustrative arithmetic, not a measured market result: 40 hits among 100 paired signals
gives 40%; 175 hits among 500 peers gives 35%. The difference is +5 pp. If 20 signals and
125 peers close above the threshold at the endpoint, the respective close rates are 20%
and 25%, a -5 pp difference. Neither number establishes profit or significance.

## Focused Verification

- Change or remove prices after a chosen signal date: earlier signal identities and peer
  matching decisions must remain unchanged, with the required warm-up history retained.
- Independently check an exact threshold hit, a touch followed by a lower close, the first
  eligible session, and each stock's baseline. Do not assume a signal-close fill is executable.
- Check that an incomplete paired group is excluded from both rates while the original
  event and exclusion reason remain recorded. Reconcile event totals with report counts.
- On identical samples, every higher-target hit must also hit the lower target. Lowering
  the target need not improve the signal-minus-peer difference.
- On a common complete sample, longer horizons cannot reduce target-touch success, but
  endpoint-close rates can fall. Comparisons using different samples need not be monotonic.
- Verify saved outputs, parameters, links, and replay prerequisites. Distinguish checks of
  signal generation, matching, outcomes, and aggregate arithmetic; do not claim all were tested.

Confidence intervals require attention to repeated stocks, overlapping windows, and shared
dates. Peer matching is observational, not causal proof. Profit claims additionally require
entry/exit rules, executable fills, loss sizes, costs, and risk to be simulated explicitly.