#!/usr/bin/env python3
"""Load the seven Olist inputs into SQLite and export aggregate reports."""

import argparse
import csv
import hashlib
import io
import json
import re
import sqlite3
import tempfile
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path, PurePosixPath
from zipfile import BadZipFile, ZipFile

from fixture import make_fixture

ROOT = Path(__file__).resolve().parent
SQL = ROOT / "sql"
DATASET_URL = "https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce"
LICENSE_URL = "https://creativecommons.org/licenses/by-nc-sa/4.0/"


def required(value):
    result = value.strip()
    if not result:
        raise ValueError
    return result


def optional(value):
    return value.strip() or None


def state_code(value):
    if re.fullmatch(r"[A-Z]{2}", value) is None:
        raise ValueError
    return value


TIMESTAMP = re.compile(r"\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}")


def timestamp(value):
    if not TIMESTAMP.fullmatch(value):
        raise ValueError
    return datetime.fromisoformat(value).isoformat(sep=" ")


def optional_timestamp(value):
    return timestamp(value) if value.strip() else None


def optional_date(value):
    return timestamp(value)[:10] if value.strip() else None


def cents(value):
    try:
        amount = Decimal(value)
        if amount.is_finite() and 0 <= amount <= Decimal("1000000000"):
            scaled = amount * 100
            if scaled == scaled.to_integral_value():
                return int(scaled)
    except InvalidOperation:
        pass
    raise ValueError


# File order follows the foreign keys. Only these fields enter SQLite.
INPUTS = {
    "olist_customers_dataset.csv": ("customers", (
        ("customer_id", required), ("customer_unique_id", required),
        ("customer_state", state_code),
    )),
    "olist_products_dataset.csv": ("products", (
        ("product_id", required), ("product_category_name", optional),
    )),
    "olist_sellers_dataset.csv": ("sellers", (("seller_id", required),)),
    "product_category_name_translation.csv": ("category_translation", (
        ("product_category_name", required), ("product_category_name_english", required),
    )),
    "olist_orders_dataset.csv": ("orders", (
        ("order_id", required), ("customer_id", required), ("order_status", required),
        ("order_purchase_timestamp", timestamp),
        ("order_delivered_customer_date", optional_timestamp),
        ("order_estimated_delivery_date", optional_date),
    )),
    "olist_order_items_dataset.csv": ("order_items", (
        ("order_id", required), ("order_item_id", int), ("product_id", required),
        ("price", cents), ("freight_value", cents), ("seller_id", required),
    )),
    "olist_order_payments_dataset.csv": ("payments", (
        ("order_id", required), ("payment_sequential", int),
        ("payment_value", cents),
    )),
}


def file_hash(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_inputs(source):
    """Yield input bytes in load order without extracting an archive."""
    if source is None:
        fixture = make_fixture()
        for name in INPUTS:
            yield name, fixture[name]
    elif source.is_dir():
        for name in INPUTS:
            yield name, (source / name).read_bytes()
    else:
        with ZipFile(source) as archive:
            by_name = {}
            for member in archive.infolist():
                name = PurePosixPath(member.filename).name
                if member.is_dir() or name not in INPUTS:
                    continue
                if name in by_name:
                    raise ValueError(f"archive contains multiple copies of {name}")
                by_name[name] = member
            missing = INPUTS.keys() - by_name.keys()
            if missing:
                raise ValueError(f"archive is missing {', '.join(sorted(missing))}")
            for name in INPUTS:
                yield name, archive.read(by_name[name])


def load_table(db, name, data):
    table, fields = INPUTS[name]
    placeholders = ", ".join("?" for _ in fields)
    insert = f"INSERT INTO {table} VALUES ({placeholders})"
    with io.TextIOWrapper(io.BytesIO(data), encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream, strict=True)
        header = reader.fieldnames or []
        if len(header) != len(set(header)):
            raise ValueError(f"{name}: duplicate field names")
        missing = {column for column, _ in fields} - set(header)
        if missing:
            raise ValueError(f"{name}: missing fields {', '.join(sorted(missing))}")

        def rows():
            for row in reader:
                if None in row or None in row.values():
                    raise ValueError(f"{name}, line {reader.line_num}: malformed CSV row")
                result = []
                for column, convert in fields:
                    try:
                        result.append(convert(row[column]))
                    except (ValueError, OverflowError):
                        raise ValueError(f"{name}, line {reader.line_num}: invalid {column}") from None
                yield result

        try:
            return db.executemany(insert, rows()).rowcount
        except (sqlite3.IntegrityError, sqlite3.DataError, OverflowError):
            raise ValueError(f"{name}, line {reader.line_num}: invalid key or value") from None


def quality_checks(db):
    if db.execute("PRAGMA quick_check").fetchone()[0] != "ok":
        raise RuntimeError("SQLite integrity check failed")
    if db.execute("PRAGMA foreign_key_check").fetchone() is not None:
        raise RuntimeError("foreign-key integrity check failed")

    observed = db.execute("""
        SELECT count(*) AS orders,
               min(date(purchased_at)) AS first_purchase_date,
               max(date(purchased_at)) AS last_purchase_date,
               count(DISTINCT customer_unique_id) AS unique_ordering_customers,
               count(*) FILTER (WHERE item_count = 0) AS orders_without_items,
               count(*) FILTER (WHERE payment_count = 0) AS orders_without_payments,
               count(*) FILTER (WHERE status = 'delivered') AS delivered_orders,
               count(*) FILTER (WHERE status = 'delivered' AND item_count = 0)
                   AS delivered_without_items,
               count(*) FILTER (WHERE status = 'delivered' AND delivered_at IS NULL)
                   AS delivered_without_delivery_timestamp,
               count(*) FILTER (WHERE status = 'delivered' AND estimated_delivery_date IS NULL)
                   AS delivered_without_estimated_date,
               count(*) FILTER (WHERE status = 'delivered' AND delivered_at < purchased_at)
                   AS delivered_timestamp_before_purchase,
               count(*) FILTER (WHERE status = 'delivered' AND estimated_delivery_date < date(purchased_at))
                   AS delivered_estimate_before_purchase_date,
               coalesce(sum(merchandise_cents) FILTER (WHERE status = 'delivered'), 0)
                   AS delivered_merchandise_cents,
               coalesce(sum(freight_cents) FILTER (WHERE status = 'delivered'), 0)
                   AS delivered_freight_cents
        FROM order_fact
    """).fetchone()
    reference = db.execute("""
        SELECT (SELECT count(*) FROM orders),
               coalesce(sum(i.price_cents), 0), coalesce(sum(i.freight_cents), 0)
        FROM order_items AS i JOIN orders AS o USING (order_id)
        WHERE o.status = 'delivered'
    """).fetchone()
    observed_totals = (observed["orders"], observed["delivered_merchandise_cents"], observed["delivered_freight_cents"])
    if not reference[0] or observed_totals != tuple(reference):
        raise RuntimeError("order-grain validation failed: compare source orders and delivered item sales")
    return dict(observed)


def export_reports(db, directory):
    reports = {}
    for query in sorted((SQL / "reports").glob("*.sql")):
        result = db.execute(query.read_text(encoding="utf-8"))
        filename = f"{query.stem}.csv"
        output = directory / filename
        with output.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream, lineterminator="\n")
            writer.writerow(field[0] for field in result.description)
            row_count = 0
            for row_count, row in enumerate(result, start=1):
                writer.writerow(row)
        reports[filename] = {"rows": row_count, "sha256": file_hash(output)}
    if not reports:
        raise RuntimeError("no report SQL files found")
    return reports


def run(input_path, output_path):
    lock = json.loads((ROOT / "source-lock.json").read_text(encoding="utf-8"))
    with sqlite3.connect(":memory:") as db:
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA temp_store = MEMORY")
        db.executescript((SQL / "10_schema.sql").read_text(encoding="utf-8"))
        inputs = {}
        for name, data in read_inputs(input_path):
            inputs[name] = {"rows": load_table(db, name, data), "sha256": hashlib.sha256(data).hexdigest()}
        db.executescript((SQL / "15_indexes.sql").read_text(encoding="utf-8"))
        db.executescript((SQL / "20_models.sql").read_text(encoding="utf-8"))
        quality = quality_checks(db)

        verified = input_path is not None and inputs == lock["inputs"]
        kind = "synthetic_fixture" if input_path is None else "user_supplied_olist_schema"
        source = {"kind": "verified_olist_v2" if verified else kind}
        if verified:
            db.execute("""
                UPDATE analysis_settings
                SET first_complete_month = '2017-01-01', last_complete_month = '2018-08-01'
                WHERE singleton = 1
            """)
            source.update({
                "title": "Brazilian E-Commerce Public Dataset by Olist",
                "publisher": "Olist", "url": DATASET_URL, "version": 2,
                "license": "CC BY-NC-SA 4.0", "license_url": LICENSE_URL,
                "first_complete_month": "2017-01-01", "last_complete_month": "2018-08-01",
                "transformations": "Selected fields, normalized types, grouped reporting, modeled scenarios.",
            })
        if input_path and input_path.is_file():
            source["archive_sha256"] = file_hash(input_path)
            source["official_archive_match"] = source["archive_sha256"] == lock["archive_sha256"]

        output_path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="olist-reports-", dir=output_path.parent) as temp:
            staging = Path(temp) / "reports"
            staging.mkdir()
            reports = export_reports(db, staging)
            manifest = {"source": source, "inputs": inputs, "quality": quality, "reports": reports}
            (staging / "manifest.json").write_text(
                json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n"
            )
            staging.rename(output_path)
    return source["kind"], quality["orders"], len(reports)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--source", type=Path, help="Olist ZIP or directory of extracted CSVs")
    mode.add_argument("--fixture", action="store_true", help="run with deterministic synthetic data")
    parser.add_argument("--out", type=Path, required=True, help="new directory for aggregate reports")
    args = parser.parse_args()
    if sqlite3.sqlite_version_info < (3, 35, 0):
        parser.error("SQLite 3.35 or newer is required")
    if args.out.exists():
        parser.error("--out already exists; choose a new directory")
    try:
        source, orders, report_count = run(args.source, args.out)
    except (OSError, ValueError, csv.Error, RuntimeError, sqlite3.Error, BadZipFile) as error:
        parser.exit(1, f"Project 03: {error}\n")
    print(f"Exported {report_count} reports from {source} ({orders:,} orders) to {args.out}.")


if __name__ == "__main__":
    main()
