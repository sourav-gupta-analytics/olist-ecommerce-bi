# Advanced SQL E-commerce Business Intelligence

An independent marketplace case study in **SQLite, Python and Power BI**. The project asks where delivered merchandise sales grew, how often buyers returned, and which delivery markets warrant investigation.

## What the analysis covers

| Business question | SQL reports |
|---|---|
| What drives sales and assortment? | Monthly growth and AOV, category rankings, product-volume tiers |
| When do customers return? | RFM segments, first-purchase cohorts, repeat purchase within 90 days |
| Where should operations investigate? | Delivery promise attainment by state, seller-volume tiers |
| How sensitive are the numbers? | Payment reconciliation and contribution-margin scenarios with stated cost assumptions |

The model rolls items and payments up to one row per order before joining them. That preserves order counts and prevents multi-item, split-payment orders from inflating merchandise sales. Cohort cells appear only for observed activity months, and the 90-day repeat denominator includes buyers with a full 90 days of follow-up.

The companion Power BI report has Sales, Retention and Delivery pages. Each page works from SQL aggregates with its own grain. The state delivery rate uses total on-time orders divided by total eligible orders, which preserves weighting.

## Run offline

Use Python 3.10 or newer with SQLite 3.35 or newer in the standard library.

```powershell
python -B run.py --fixture --out build/fixture
python -B -m unittest -v
```

The built-in fixture uses invented transactions to exercise split payments, missing records, cohort eligibility and reporting thresholds. The runner writes ten CSV reports and a manifest with checksums into the requested new output folder.

## Reproduce the historical case

Download version 2 from [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). Supply the original ZIP or a directory of its extracted CSVs.

```powershell
python -B run.py --source "C:/path/to/olist-v2.zip" --out build/olist
```

`source-lock.json` fingerprints the seven loaded inputs. A match is labeled `verified_olist_v2` in the manifest. The manifest also records report checksums, row counts and integrity checks. The Olist run uses January 2017–August 2018 for monthly comparisons and cohort observation, with earlier delivered purchases retained in buyer history.

## Project files

- [Schema and order-grain model](sql/) · [Ten report queries](sql/reports/)
- [Data provenance and field allowlist](docs/DATA_PROVENANCE.md)
- [Hinglish SQL and interview walkthrough](docs/HINGLISH_GUIDE.md)

The repository source package includes implementation, documentation and a synthetic fixture. Historical inputs and report artifacts have their own provenance and distribution review. Olist and its collaborators released the historical dataset under CC BY-NC-SA 4.0. This analysis selects fields, normalizes types and produces grouped reports. [Original dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) · [Dataset license](https://creativecommons.org/licenses/by-nc-sa/4.0/)
