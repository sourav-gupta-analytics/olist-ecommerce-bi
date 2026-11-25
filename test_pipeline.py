"""Regression checks for the joins, observation windows and aggregate exports."""

import csv
import json
import tempfile
import unittest
from pathlib import Path

import run


class PipelineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        cls.output = cls.directory / "first"
        run.run(None, cls.output)

    def report(self, name):
        with (self.output / name).open(encoding="utf-8", newline="") as source:
            return list(csv.DictReader(source))

    def test_order_grain_and_reconciliation(self):
        months = {row["month_start"]: row for row in self.report("01_monthly_kpis.csv")}
        january = months["2024-01-01"]
        self.assertEqual(int(january["delivered_order_count"]), 1)
        self.assertEqual(float(january["merchandise_sales_brl"]), 160.0)
        self.assertEqual(float(january["freight_charged_brl"]), 10.0)

        total = self.report("02_payment_reconciliation.csv")[0]
        self.assertEqual(int(total["order_count"]), 31)
        self.assertEqual(int(total["comparable_orders"]), 29)
        self.assertEqual(int(total["mismatched_orders"]), 1)
        self.assertEqual(float(total["net_payment_delta_brl"]), -0.02)
        self.assertEqual(int(total["missing_payment_orders"]), 1)

    def test_calendar_and_customer_identity(self):
        months = {row["month_start"]: row for row in self.report("01_monthly_kpis.csv")}
        self.assertEqual(months["2024-06-01"]["month_coverage"], "partial")
        self.assertEqual(int(months["2024-03-01"]["order_count"]), 0)
        self.assertEqual(float(months["2024-03-01"]["merchandise_sales_mom_pct"]), -100.0)
        self.assertEqual(months["2024-04-01"]["merchandise_sales_mom_pct"], "")

        repeat = self.report("06_repeat_purchase.csv")[0]
        self.assertEqual(int(repeat["delivered_customers"]), 28)
        self.assertEqual(int(repeat["eligible_customers_90d"]), 3)
        self.assertEqual(int(repeat["repeat_customers_within_90d"]), 1)

        cohort = [
            row for row in self.report("05_cohort_retention.csv")
            if row["cohort_month"] == "2024-01-01"
        ]
        self.assertEqual([int(row["active_customers"]) for row in cohort], [1, 1, 0, 0, 0])
        self.assertEqual(cohort[-1]["activity_month"], "2024-05-01")

    def test_aggregate_disclosure_and_sla(self):
        regions = self.report("07_delivery_by_state.csv")
        self.assertEqual([row["state"] for row in regions], ["SP"])
        self.assertEqual(int(regions[0]["sla_eligible_orders"]), 26)
        self.assertEqual(int(regions[0]["on_time_orders"]), 25)
        self.assertEqual(int(regions[0]["late_orders"]), 1)

        categories = self.report("03_category_performance.csv")
        self.assertEqual([row["category"] for row in categories], ["books"])
        self.assertEqual(float(categories[0]["merchandise_sales_brl"]), 485.0)

        sellers = self.report("09_seller_volume_tiers.csv")
        self.assertEqual([int(row["seller_count"]) for row in sellers], [25])
        products = self.report("10_product_volume_tiers.csv")
        self.assertEqual([int(row["product_count"]) for row in products], [26])
        for report in self.output.glob("*.csv"):
            contents = report.read_text(encoding="utf-8")
            for private_value in ("buyer-a", "bulk-order-", "bulk-seller-", "bulk-product-"):
                self.assertNotIn(private_value, contents)

    def test_reports_are_reproducible(self):
        manifest = json.loads((self.output / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["source"]["kind"], "synthetic_fixture")
        self.assertEqual(len(manifest["reports"]), 10)
        second = self.directory / "second"
        run.run(None, second)
        for file in self.output.iterdir():
            self.assertEqual(file.read_bytes(), (second / file.name).read_bytes(), file.name)


if __name__ == "__main__":
    unittest.main()
