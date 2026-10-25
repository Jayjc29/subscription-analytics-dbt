"""Generate a synthetic SaaS dataset: users, subscription events and product events.

The output is deterministic (fixed seed), so local runs and CI build the same data.
Three real-world problems are injected on purpose so the dbt models have something to handle:

* ~1% of product events are delivered twice with the same event_id -> deduplicated in staging.
* ~3% of product events arrive 1-3 days after they happened -> the incremental model reprocesses
  a 3-day lookback window so late events still land in the right day.
* All timestamps are UTC, but the business reports in IST (UTC+5:30). Anything after 18:30 UTC is
  already the next day in IST, so bucketing by UTC date puts it in the wrong day and week.
"""

import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

SEED = 42
N_USERS = 5000
SIGNUP_START = datetime(2025, 1, 1)
SIGNUP_END = datetime(2025, 12, 31, 23, 59, 59)
AS_OF = datetime(2026, 3, 31, 23, 59, 59)
TRIAL_DAYS = 14
PLAN_PRICE_USD = {"pro": 15, "team": 45}
KEY_ACTIONS = ["create_project", "upload_file", "export_report"]
OTHER_ACTIONS = ["login", "invite_teammate"]
EVENT_WEIGHTS = [20, 25, 10, 40, 5]
DUPLICATE_RATE = 0.01
LATE_RATE = 0.03
OUT_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"

rng = random.Random(SEED)
fmt = "%Y-%m-%d %H:%M:%S"


def random_ts(start: datetime, end: datetime) -> datetime:
    return start + timedelta(seconds=rng.uniform(0, (end - start).total_seconds()))


class EventWriter:
    def __init__(self) -> None:
        self.rows: list[list[str]] = []
        self.n = 0

    def day_of_activity(self, user_id: str, day_start: datetime) -> int:
        """Write 1-4 events at random times on one day; return how many were key actions."""
        key = 0
        for _ in range(rng.randint(1, 4)):
            event_at = day_start + timedelta(seconds=rng.uniform(0, 86_399))
            if event_at > AS_OF:
                continue
            event_type = rng.choices(KEY_ACTIONS + OTHER_ACTIONS, weights=EVENT_WEIGHTS)[0]
            key += event_type in KEY_ACTIONS
            self.n += 1
            event_id = f"e_{self.n:08d}"
            lag = timedelta(days=rng.uniform(1, 3)) if rng.random() < LATE_RATE else timedelta(seconds=rng.uniform(5, 600))
            ingested_at = event_at + lag
            self.rows.append([event_id, user_id, event_type, event_at.strftime(fmt), ingested_at.strftime(fmt)])
            if rng.random() < DUPLICATE_RATE:
                # Same event re-sent by the client a few minutes later.
                resent = ingested_at + timedelta(minutes=rng.uniform(1, 30))
                self.rows.append([event_id, user_id, event_type, event_at.strftime(fmt), resent.strftime(fmt)])
        return key


def main() -> None:
    users, subs = [], []
    events = EventWriter()
    sub_n = 0

    def sub_event(user_id: str, event_type: str, plan: str, mrr: int, at: datetime) -> None:
        nonlocal sub_n
        sub_n += 1
        subs.append([f"s_{sub_n:07d}", user_id, event_type, plan, mrr, at.strftime(fmt)])

    for i in range(1, N_USERS + 1):
        user_id = f"u_{i:05d}"
        signup = random_ts(SIGNUP_START, SIGNUP_END)
        country = rng.choices(["IN", "US", "GB", "DE", "SG", "AE"], weights=[50, 22, 10, 7, 6, 5])[0]
        channel = rng.choices(["organic", "paid_search", "referral", "partner"], weights=[45, 30, 15, 10])[0]
        users.append([user_id, signup.strftime(fmt), country, channel])
        engagement = rng.betavariate(2, 3)

        sub_event(user_id, "trial_started", "pro", 0, signup)
        key_first_week = 0
        for day in range(TRIAL_DAYS):
            if rng.random() < engagement:
                key = events.day_of_activity(user_id, signup + timedelta(days=day))
                if day < 7:
                    key_first_week += key

        trial_end = signup + timedelta(days=TRIAL_DAYS)
        p_convert = 0.04 + 0.35 * engagement + (0.12 if key_first_week >= 3 else 0.0)
        if trial_end <= AS_OF and rng.random() < p_convert:
            plan = "team" if rng.random() < 0.2 else "pro"
            period_start = trial_end + timedelta(hours=rng.uniform(0, 48))
            sub_event(user_id, "converted", plan, PLAN_PRICE_USD[plan], period_start)
            while period_start + timedelta(days=30) <= AS_OF:
                for day in range(30):
                    if rng.random() < engagement * 0.7:
                        events.day_of_activity(user_id, period_start + timedelta(days=day))
                roll = rng.random()
                if roll < 0.04 and plan == "pro":
                    plan = "team"
                    sub_event(user_id, "plan_changed", plan, PLAN_PRICE_USD[plan], random_ts(period_start, period_start + timedelta(days=30)))
                elif roll < 0.06 and plan == "team":
                    plan = "pro"
                    sub_event(user_id, "plan_changed", plan, PLAN_PRICE_USD[plan], random_ts(period_start, period_start + timedelta(days=30)))
                if rng.random() < max(0.01, 0.09 - 0.07 * engagement):
                    sub_event(user_id, "canceled", plan, 0, min(AS_OF, period_start + timedelta(days=30, hours=rng.uniform(0, 72))))
                    break
                period_start += timedelta(days=30)
        else:
            # Free users drift away: each later month is less likely to see activity.
            for month in range(1, 7):
                if rng.random() < engagement * (0.5 ** month):
                    for _ in range(rng.randint(1, 4)):
                        events.day_of_activity(user_id, trial_end + timedelta(days=30 * (month - 1) + rng.uniform(0, 29)))

    # Order the log the way a source export would arrive: grouped by user, oldest event first.
    subs.sort(key=lambda r: (r[1], r[5]))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, header, rows in [
        ("users", ["user_id", "signup_at_utc", "country", "acquisition_channel"], users),
        ("subscription_events", ["event_id", "user_id", "event_type", "plan", "mrr_usd", "event_at_utc"], subs),
        ("product_events", ["event_id", "user_id", "event_type", "event_at_utc", "ingested_at_utc"], events.rows),
    ]:
        with open(OUT_DIR / f"{name}.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(header)
            w.writerows(rows)
        print(f"{name:>20}: {len(rows):>8,} rows")


if __name__ == "__main__":
    main()
