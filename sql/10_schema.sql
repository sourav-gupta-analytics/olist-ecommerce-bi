PRAGMA foreign_keys = ON;

CREATE TABLE customers (
    customer_id TEXT PRIMARY KEY NOT NULL,
    customer_unique_id TEXT NOT NULL,
    state TEXT NOT NULL
) WITHOUT ROWID;

CREATE TABLE products (
    product_id TEXT PRIMARY KEY NOT NULL,
    category TEXT
) WITHOUT ROWID;

CREATE TABLE sellers (
    seller_id TEXT PRIMARY KEY NOT NULL
) WITHOUT ROWID;

CREATE TABLE category_translation (
    category TEXT PRIMARY KEY NOT NULL,
    category_english TEXT NOT NULL
) WITHOUT ROWID;

CREATE TABLE orders (
    order_id TEXT PRIMARY KEY NOT NULL,
    customer_id TEXT NOT NULL REFERENCES customers(customer_id),
    status TEXT NOT NULL,
    purchased_at TEXT NOT NULL,
    delivered_at TEXT,
    estimated_delivery_date TEXT
) WITHOUT ROWID;

CREATE TABLE order_items (
    order_id TEXT NOT NULL REFERENCES orders(order_id),
    item_number INTEGER NOT NULL CHECK (item_number > 0),
    product_id TEXT NOT NULL REFERENCES products(product_id),
    price_cents INTEGER NOT NULL CHECK (price_cents >= 0),
    freight_cents INTEGER NOT NULL CHECK (freight_cents >= 0),
    seller_id TEXT NOT NULL REFERENCES sellers(seller_id),
    PRIMARY KEY (order_id, item_number)
) WITHOUT ROWID;

CREATE TABLE payments (
    order_id TEXT NOT NULL REFERENCES orders(order_id),
    payment_number INTEGER NOT NULL CHECK (payment_number > 0),
    payment_cents INTEGER NOT NULL CHECK (payment_cents >= 0),
    PRIMARY KEY (order_id, payment_number)
) WITHOUT ROWID;

CREATE TABLE analysis_settings (
    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
    first_complete_month TEXT,
    last_complete_month TEXT
);
INSERT INTO analysis_settings VALUES (1, NULL, NULL);
