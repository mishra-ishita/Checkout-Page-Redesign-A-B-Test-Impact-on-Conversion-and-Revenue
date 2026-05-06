# ==============================
# A/B TEST DATA GENERATOR SCRIPT
# ==============================

import pandas as pd
import numpy as np
import random
from datetime import datetime, timedelta

# ------------------------------
# 1. CONFIG
# ------------------------------
np.random.seed(42)

NUM_USERS = 1200
EXPERIMENT_ID = "EXP_001"

# ------------------------------
# 2. GENERATE USERS TABLE
# ------------------------------
user_ids = [f"U{1000+i}" for i in range(NUM_USERS)]

users = pd.DataFrame({
    "user_id": user_ids,
    "signup_date": [
        datetime(2024, 1, 1) + timedelta(days=random.randint(0, 120))
        for _ in range(NUM_USERS)
    ],
    "country": ["India"] * NUM_USERS,
    "city": np.random.choice(
        ["Gurgaon", "Delhi", "Mumbai", "Bangalore"], NUM_USERS
    ),
    "device_type": np.random.choice(
        ["mobile", "desktop"], NUM_USERS, p=[0.7, 0.3]
    ),
    "traffic_source": np.random.choice(
        ["ads", "organic", "referral"], NUM_USERS
    ),
    "is_returning": np.random.choice([True, False], NUM_USERS)
})

print("Users table created:", users.shape)

# ------------------------------
# 3. EXPERIMENT ASSIGNMENT
# ------------------------------
experiment_assignment = pd.DataFrame({
    "user_id": user_ids,
    "experiment_id": EXPERIMENT_ID,
    "variant": np.random.choice(["A", "B"], NUM_USERS),
    "assignment_timestamp": [
        datetime(2024, 4, 1) + timedelta(minutes=random.randint(0, 5000))
        for _ in range(NUM_USERS)
    ]
})

print("Experiment table created:", experiment_assignment.shape)

# ------------------------------
# 4. EVENTS TABLE (FUNNEL)
# ------------------------------
events_data = []
event_id = 1

for user in user_ids:
    sessions = random.randint(1, 3)

    for _ in range(sessions):
        session_id = f"S{random.randint(1000,9999)}"
        base_time = datetime(2024, 4, 1) + timedelta(minutes=random.randint(0, 10000))

        # Funnel logic (realistic drop-offs)
        steps = ["view"]

        if random.random() < 0.7:
            steps.append("add_to_cart")

        if random.random() < 0.5:
            steps.append("checkout")

        if random.random() < 0.4:
            steps.append("purchase")

        for i, step in enumerate(steps):
            events_data.append([
                f"E{event_id}",
                user,
                session_id,
                step,
                base_time + timedelta(minutes=i * 5),
                f"page_{step}",
                True
            ])
            event_id += 1

events = pd.DataFrame(events_data, columns=[
    "event_id",
    "user_id",
    "session_id",
    "event_name",
    "event_timestamp",
    "page",
    "experiment_exposed_flag"
])

print("Events table created:", events.shape)

# ------------------------------
# 5. TRANSACTIONS TABLE
# ------------------------------
transactions_data = []
order_id = 1000

purchase_events = events[events["event_name"] == "purchase"]

for _, row in purchase_events.iterrows():
    transactions_data.append([
        f"O{order_id}",
        row["user_id"],
        row["event_timestamp"],
        round(random.uniform(200, 2000), 2),
        random.choice(["UPI", "Card", "Wallet"])
    ])
    order_id += 1

transactions = pd.DataFrame(transactions_data, columns=[
    "order_id",
    "user_id",
    "transaction_timestamp",
    "revenue",
    "payment_method"
])

print("Transactions table created:", transactions.shape)

# ------------------------------
# 6. SAVE TO CSV
# ------------------------------
users.to_csv("users.csv", index=False)
experiment_assignment.to_csv("experiment_assignment.csv", index=False)
events.to_csv("events.csv", index=False)
transactions.to_csv("transactions.csv", index=False)

print("\n✅ All CSV files generated successfully!")

# ------------------------------
# 7. QUICK VALIDATION (IMPORTANT)
# ------------------------------

print("\n--- BASIC CHECKS ---")

# Users count
print("Total Users:", users["user_id"].nunique())

# Variant split
print("\nVariant Distribution:")
print(experiment_assignment["variant"].value_counts(normalize=True))

# Funnel counts
print("\nFunnel Counts:")
print(events["event_name"].value_counts())

# Conversion rate
converted_users = transactions["user_id"].nunique()
total_users = users["user_id"].nunique()

print("\nConversion Rate:",
      round(converted_users / total_users * 100, 2), "%")