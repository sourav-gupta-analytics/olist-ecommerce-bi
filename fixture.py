"""Deterministic invented orders, using the same CSV inputs as the real run."""

import csv
import io


def csv_bytes(columns, rows):
    stream = io.StringIO(newline="")
    writer = csv.writer(stream, lineterminator="\n")
    writer.writerow(columns)
    writer.writerows(rows)
    return stream.getvalue().encode("utf-8")


def make_fixture():
    customers = [
        ("c0", "pre-window", "RJ"),
        ("c1", "buyer-a", "SP"),
        ("c2", "buyer-a", "SP"),
        ("c3", "buyer-b", "SP"),
        ("c4", "buyer-c", "RJ"),
        ("c5", "buyer-d", "RJ"),
        ("c6", "buyer-e", "RJ"),
    ]
    orders = [
        ("o0", "c0", "delivered", "2023-12-15 10:00:00", "2023-12-19 11:00:00", "2023-12-20 00:00:00"),
        ("o1", "c1", "delivered", "2024-01-02 10:00:00", "2024-01-05 13:30:00", "2024-01-05 00:00:00"),
        ("o2", "c2", "delivered", "2024-02-01 10:00:00", "2024-02-09 09:00:00", "2024-02-07 00:00:00"),
        ("o3", "c3", "delivered", "2024-02-10 10:00:00", "", "2024-02-16 00:00:00"),
        ("o4", "c4", "canceled", "2024-04-15 10:00:00", "", "2024-04-17 00:00:00"),
        ("o5", "c5", "delivered", "2024-05-20 10:00:00", "2024-05-24 12:00:00", "2024-05-26 00:00:00"),
        ("o6", "c6", "unavailable", "2024-06-12 10:00:00", "", "2024-06-16 00:00:00"),
    ]
    items = [
        ("o0", 1, "p1", "25.00", "2.00", "s1"),
        ("o1", 1, "p1", "100.00", "5.00", "s1"),
        ("o1", 2, "p2", "60.00", "5.00", "s2"),
        ("o2", 1, "p3", "40.00", "5.00", "s1"),
        ("o3", 1, "p1", "50.00", "5.00", "s1"),
        ("o5", 1, "p1", "70.00", "5.00", "s1"),
    ]
    payments = [
        ("o0", 1, "card", "27.00"),
        ("o1", 1, "card", "150.00"),
        ("o1", 2, "voucher", "20.00"),
        ("o2", 1, "card", "45.00"),
        ("o3", 1, "card", "54.98"),
        ("o4", 1, "card", "15.00"),
        ("o5", 1, "card", "75.00"),
    ]

    # Twenty-four invented orders exercise the threshold in the SP state report.
    for index in range(24):
        order_id = f"bulk-order-{index:02d}"
        customer_id = f"bulk-order-customer-{index:02d}"
        seller_id = f"bulk-seller-{index:02d}"
        customers.append((customer_id, f"bulk-buyer-{index:02d}", "SP"))
        orders.append((
            order_id, customer_id, "delivered", "2024-04-05 09:00:00",
            "2024-04-10 11:00:00", "2024-04-10 00:00:00",
        ))
        items.append((order_id, 1, f"bulk-product-{index:02d}", "10.00", "2.00", seller_id))
        payments.append((order_id, 1, "card", "12.00"))

    return {
        "olist_customers_dataset.csv": csv_bytes(
            ("customer_id", "customer_unique_id", "customer_state"), customers
        ),
        "olist_products_dataset.csv": csv_bytes(
            ("product_id", "product_category_name"),
            [("p1", "livros"), ("p2", ""), ("p3", "sem_traducao")]
            + [(f"bulk-product-{index:02d}", "livros") for index in range(24)],
        ),
        "olist_sellers_dataset.csv": csv_bytes(
            ("seller_id", "seller_state"),
            [("s1", "SP"), ("s2", "RJ")] + [(f"bulk-seller-{index:02d}", "SP") for index in range(24)],
        ),
        "product_category_name_translation.csv": csv_bytes(
            ("product_category_name", "product_category_name_english"), [("livros", "books")]
        ),
        "olist_orders_dataset.csv": csv_bytes(
            ("order_id", "customer_id", "order_status", "order_purchase_timestamp",
             "order_delivered_customer_date", "order_estimated_delivery_date"), orders,
        ),
        "olist_order_items_dataset.csv": csv_bytes(
            ("order_id", "order_item_id", "product_id", "price", "freight_value", "seller_id"), items,
        ),
        "olist_order_payments_dataset.csv": csv_bytes(
            ("order_id", "payment_sequential", "payment_type", "payment_value"), payments,
        ),
    }
