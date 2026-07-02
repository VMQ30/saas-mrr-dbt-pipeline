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


def inject_null(value, probability=0.05):
    return "" if random.random() < probability else value


def mess_up_string(text, probability=0.1):
    if random.random() > probability:
        return text

    mutations = [
        lambda t: t.upper(),
        lambda t: t.capitalize(),
        lambda t: f" {t} ",
    ]
    return random.choice(mutations)(text)


def mess_up_date(dt_obj, probability=0.05):
    if random.random() > probability:
        return dt_obj.strftime("%Y-%m-%d %H:%M:%S")

    formats = [
        lambda d: d.strftime("%Y/%m/%d"),
        lambda d: d.isoformat(),
        lambda d: str(int(d.timestamp())),
        lambda d: "NULL",
    ]
    return random.choice(formats)(dt_obj)


def mock_data(num_customers: int = 500):
    fake = Faker()
    start_date = datetime(2024, 1, 1)
    end_date = datetime.now()

    customer_file_exists = (
        os.path.isfile(CUSTOMER_FILE) and os.path.getsize(CUSTOMER_FILE) > 0
    )
    subscription_file_exists = (
        os.path.isfile(SUBSCRIPTION_FILE) and os.path.getsize(SUBSCRIPTION_FILE) > 0
    )

    customer_index = get_last_id(CUSTOMER_FILE, "customer_id")
    event_id = get_last_id(SUBSCRIPTION_FILE, "event_id")

    customers = []
    events = []

    for i in range(customer_index, customer_index + num_customers):
        customer_id = f"{i:05d}"
        created_at_dt = fake.date_time_between(start_date=start_date, end_date=end_date)

        cust_record = {
            "customer_id": customer_id,
            "customer_name": inject_null(fake.name(), probability=0.05),
            "country": inject_null(fake.country_code(), probability=0.08),
            "created_at": mess_up_date(created_at_dt),  # FIX: Passed datetime object
        }
        customers.append(cust_record)

        if random.random() < 0.03:
            customers.append(cust_record.copy())

        current_plan = random.choice(list(PLANS.keys()))
        current_date = created_at_dt

        signup_event = {
            "event_id": event_id,
            "customer_id": customer_id,
            "event_type": "signup",
            "plan_name": mess_up_string(current_plan, probability=0.15),
            "amount": PLANS[current_plan],
            "event_timestamp": mess_up_date(current_date),
        }
        events.append(signup_event)

        if random.random() < 0.03:
            events.append(signup_event.copy())

        event_id += 1

        while current_date < end_date:
            current_date += timedelta(days=random.randint(30, 180))
            if current_date > end_date:
                break

            action = random.choices(ACTION_TYPES, weights=ACTION_WEIGHTS)[0]

            if action == "churn":
                churn_event = {
                    "event_id": event_id,
                    "customer_id": customer_id,
                    "event_type": "churn",
                    "plan_name": "none",
                    "amount": 0.00,
                    "event_timestamp": mess_up_date(current_date),
                }
                events.append(churn_event)
                event_id += 1
                break

            elif action == "upgrade/downgrade":
                new_plan = random.choice([p for p in PLANS if p != current_plan])
                change_event = {
                    "event_id": event_id,
                    "customer_id": customer_id,
                    "event_type": "plan_change",
                    "plan_name": mess_up_string(new_plan, probability=0.15),
                    "amount": PLANS[new_plan],
                    "event_timestamp": mess_up_date(current_date),
                }
                events.append(change_event)
                current_plan = new_plan
                event_id += 1

    if customers:
        with open(CUSTOMER_FILE, "a", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=customers[0].keys())
            if not customer_file_exists:
                writer.writeheader()
            writer.writerows(customers)

    if events:
        with open(SUBSCRIPTION_FILE, "a", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=events[0].keys())
            if not subscription_file_exists:
                writer.writeheader()
            writer.writerows(events)

    print("CSV files generated successfully!")


if __name__ == "__main__":
    mock_data(num_customers=500)
