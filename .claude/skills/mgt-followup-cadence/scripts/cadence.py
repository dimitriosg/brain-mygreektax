#!/usr/bin/env python3
"""
Cadence calculator for MyGreekTax follow ups.

Counts Greek working days between the last outbound contact and today, then
returns the cadence verdict. The point of a script rather than mental
arithmetic is that Greek public holidays are movable (Orthodox Easter shifts
the whole spring cluster) and getting them wrong by two days is exactly how a
follow up goes out too early.

Usage:
    python cadence.py --last-outbound 2026-07-14
    python cadence.py --last-outbound 2026-07-02 --followups-sent 1
    python cadence.py --last-outbound 2026-06-20 --today 2026-07-24

Verdicts:
    WAIT      window has not opened, holds until the given date
    SEND      inside the 5 to 7 working day window, send the single follow up
    OVERDUE   past the window with no follow up sent, send now or park
    PARK      the one follow up has been sent, cadence is exhausted
"""

import argparse
from datetime import date, timedelta

# Greek public holidays. Movable feasts are anchored to Orthodox Easter:
# 2026-04-12 and 2027-05-02. Verify these against a current calendar before
# relying on them for anything with a statutory deadline attached.
HOLIDAYS = {
    # 2026
    date(2026, 1, 1),    # New Year
    date(2026, 1, 6),    # Epiphany
    date(2026, 2, 23),   # Clean Monday
    date(2026, 3, 25),   # Independence Day
    date(2026, 4, 10),   # Good Friday
    date(2026, 4, 13),   # Easter Monday
    date(2026, 5, 1),    # Labour Day
    date(2026, 6, 1),    # Holy Spirit Monday
    date(2026, 8, 15),   # Dormition
    date(2026, 10, 28),  # Ohi Day
    date(2026, 12, 25),  # Christmas
    date(2026, 12, 26),  # Boxing Day
    # 2027
    date(2027, 1, 1),
    date(2027, 1, 6),
    date(2027, 3, 15),   # Clean Monday
    date(2027, 3, 25),
    date(2027, 4, 30),   # Good Friday
    date(2027, 5, 1),
    date(2027, 5, 3),    # Easter Monday
    date(2027, 6, 21),   # Holy Spirit Monday
    date(2027, 8, 15),
    date(2027, 10, 28),
    date(2027, 12, 25),
    date(2027, 12, 26),
}

WINDOW_OPEN = 5
WINDOW_CLOSE = 7


def is_working_day(d):
    return d.weekday() < 5 and d not in HOLIDAYS


def working_days_between(start, end):
    """Working days strictly after start, up to and including end."""
    if end <= start:
        return 0
    count = 0
    cursor = start + timedelta(days=1)
    while cursor <= end:
        if is_working_day(cursor):
            count += 1
        cursor += timedelta(days=1)
    return count


def add_working_days(start, n):
    cursor = start
    added = 0
    while added < n:
        cursor += timedelta(days=1)
        if is_working_day(cursor):
            added += 1
    return cursor


def verdict(last_outbound, today, followups_sent):
    elapsed = working_days_between(last_outbound, today)

    if followups_sent >= 1:
        return {
            "verdict": "PARK",
            "elapsed": elapsed,
            "detail": (
                "One follow up has already gone out. The cadence is one follow up, "
                "then stop. Park the case with a clean closing note rather than "
                "chasing again."
            ),
        }

    if elapsed < WINDOW_OPEN:
        opens = add_working_days(last_outbound, WINDOW_OPEN)
        return {
            "verdict": "WAIT",
            "elapsed": elapsed,
            "detail": (
                f"{elapsed} working days elapsed. The window opens on "
                f"{opens.isoformat()} ({opens.strftime('%A')}). Silence before then "
                "is deliberate, not neglect."
            ),
        }

    if elapsed <= WINDOW_CLOSE:
        closes = add_working_days(last_outbound, WINDOW_CLOSE)
        return {
            "verdict": "SEND",
            "elapsed": elapsed,
            "detail": (
                f"{elapsed} working days elapsed. Inside the window, which closes "
                f"{closes.isoformat()}. Send the single follow up now."
            ),
        }

    return {
        "verdict": "OVERDUE",
        "elapsed": elapsed,
        "detail": (
            f"{elapsed} working days elapsed, past the 7 day window with no follow "
            "up sent. Either send it now and accept the delay, or park directly if "
            "the lead has gone cold. Do not send and then plan a second."
        ),
    }


def main():
    p = argparse.ArgumentParser(description="MyGreekTax follow up cadence check")
    p.add_argument("--last-outbound", required=True,
                   help="date of last outbound contact, YYYY-MM-DD")
    p.add_argument("--today", default=None,
                   help="override today's date, YYYY-MM-DD")
    p.add_argument("--followups-sent", type=int, default=0,
                   help="how many follow ups have already gone out on this case")
    args = p.parse_args()

    last = date.fromisoformat(args.last_outbound)
    today = date.fromisoformat(args.today) if args.today else date.today()

    result = verdict(last, today, args.followups_sent)

    print(f"VERDICT: {result['verdict']}")
    print(f"WORKING DAYS ELAPSED: {result['elapsed']}")
    print(f"LAST OUTBOUND: {last.isoformat()} ({last.strftime('%A')})")
    print(f"TODAY: {today.isoformat()} ({today.strftime('%A')})")
    print(f"DETAIL: {result['detail']}")


if __name__ == "__main__":
    main()
