import csv
import os
import random
from collections import deque
from datetime import datetime, timedelta
from faker import Faker

CUSTOMER_FILE = "raw_customers.csv"
SUBSCRIPTION_FILE = "raw_subscription_events.csv"
PLANS = {"basic": 9.99, "pro": 24.99, "enterprise": 100.00}
ACTION_TYPES = ["upgrade/downgrade", "churn", "nothing"]
ACTION_WEIGHTS = [0.3, 0.1, 0.6]


def get_last_id(file_path, field_name):
    if not os.path.isfile(file_path) or os.path.getsize(file_path) == 0:
        return 1

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            last_line = deque(f, maxlen=1)
            if not last_line:
                return 1

            f.seek(0)
            header = f.readline().strip().split(",")
            reader = csv.DictReader([last_line[0]], fieldnames=header)
            last_row = next(reader)
            return int(last_row[field_name]) + 1

    except (IndexError, ValueError, KeyError):
        return 1


def mock_data(num_customers: int = 500):
    fake = Faker()
    start_date = datetime(2024, 1, 1)
    end_date = datetime.now()

    customer_index = get_last_id(CUSTOMER_FILE, "customer_id")
    event_id = get_last_id(SUBSCRIPTION_FILE, "event_id")

    customers = []
    events = []

    for i in range(customer_index, customer_index + num_customers):
        customer_id = f"{i:05d}"
        created_at_dt = fake.date_time_between(start_date=start_date, end_date=end_date)

        customers.append(
            {
                "customer_id": customer_id,
                "customer_name": fake.name(),
                "country": fake.country_code(),
                "created_at": created_at_dt.strftime("%Y-%m-%d %H:%M:%S"),
            }
        )

        current_plan = random.choice(list(PLANS.keys()))
        current_date = created_at_dt

        events.append(
            {
                "event_id": event_id,
                "customer_id": customer_id,
                "event_type": "signup",
                "plan_name": current_plan,
                "amount": PLANS[current_plan],
                "event_timestamp": current_date.strftime("%Y-%m-%d %H:%M:%S"),
            }
        )
        event_id += 1

        while current_date < end_date:
            current_date += timedelta(days=random.randint(30, 180))
            if current_date > end_date:
                break

            action = random.choices(ACTION_TYPES, weights=ACTION_WEIGHTS)[0]

            if action == "churn":
                events.append(
                    {
                        "event_id": event_id,
                        "customer_id": customer_id,
                        "event_type": "churn",
                        "plan_name": "none",
                        "amount": 0.00,
                        "event_timestamp": current_date.strftime("%Y-%m-%d %H:%M:%S"),
                    }
                )
                event_id += 1
                break

            elif action == "upgrade/downgrade":
                new_plan = random.choice([p for p in PLANS if p != current_plan])
                events.append(
                    {
                        "event_id": event_id,
                        "customer_id": customer_id,
                        "event_type": "plan_change",
                        "plan_name": new_plan,
                        "amount": PLANS[new_plan],
                        "event_timestamp": current_date.strftime("%Y-%m-%d %H:%M:%S"),
                    }
                )
                current_plan = new_plan
                event_id += 1

    with open(CUSTOMER_FILE, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=customers[0].keys())
        if not os.path.isfile(CUSTOMER_FILE):
            writer.writeheader()
        writer.writerows(customers)

    with open(SUBSCRIPTION_FILE, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=events[0].keys())
        if not os.path.isfile(SUBSCRIPTION_FILE):
            writer.writeheader()
        writer.writerows(events)

    print("CSV files generated successfully!")


mock_data(num_customers=500)
