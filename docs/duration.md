# Parking duration behavior

Phase 4 keeps expiry calculations in pure Dart code so the same calculation
can be used by a future entry form and persistence layer. The calculator does
not read the system clock, call Flutter, or call Supabase.

## Supported units

- **Minutes** and **hours** use elapsed `Duration` arithmetic.
- **Days** use calendar arithmetic and preserve the input time of day.
- **Months** use calendar arithmetic and preserve the input time of day.

Month-end overflow is clamped to the last valid day in the target month. For
example, January 31 plus one month becomes February 28 in a non-leap year and
February 29 in a leap year.

For multiple months, the target month is calculated directly from the original
entry date rather than applying one month at a time. Therefore, January 31
plus two months becomes March 31, not March 28.

## DateTime context

The calculator preserves the input `DateTime` context. A UTC input produces a
UTC result, and a local input produces a local result. It does not implicitly
convert values to UTC; the future persistence layer is responsible for storing
timestamps consistently in PostgreSQL `TIMESTAMPTZ`.

Calendar-day and calendar-month construction uses Dart's `DateTime`
normalization. If a local calendar result falls in a nonexistent daylight-saving
time, Dart normalizes that value according to its platform rules. No timezone
package or hardcoded regional timezone is introduced in this phase.

## Invalid input

The public calculation method returns a typed failure result instead of
throwing for invalid duration values:

- `nonPositiveValue` represents zero or negative durations.
- `outOfRange` represents a result outside Dart's supported `DateTime` range.

The unit is represented by a type-safe enum, so unsupported units cannot be
constructed through the domain API. Parsing external strings belongs to a
future data boundary and must reject unknown values before creating a domain
duration.

## Expiry status

A session is **active** when the current time is strictly before `expiresAt`.
It is **expired** at the exact expiry instant and afterward. Status is computed
when requested; no background job is needed.
