CREATE INDEX idx_orders_status_purchased_at ON orders (status, purchased_at);
CREATE INDEX idx_orders_customer_id ON orders (customer_id);
ANALYZE;
