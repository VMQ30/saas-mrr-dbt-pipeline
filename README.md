# SaaS MRR dbt Pipeline

A dbt-based analytics engineering project that turns raw SaaS customer and subscription event data into a monthly recurring revenue (MRR) mart for reporting and trend analysis.

This repository is designed as a practical example of a modern warehouse transformation pipeline with:

- raw ingestion sources for customer and event history
- staged and cleaned models for standardization
- intermediate models for month spine generation and customer-month MRR progression
- a final fact model that classifies revenue changes as new, active, churn, upgrade, or downgrade
- mock data generation to bootstrap a realistic dataset for local testing

## Project Overview

The project models a subscription business where customers can:

- sign up for a plan
- upgrade or downgrade plans
- churn from the service

The resulting analytics layer answers questions such as:

- What is the MRR per customer by month?
- Which customers are expanding, contracting, or churning?
- How has the business revenue evolved over time?

## What This Repo Contains

At a high level, the repository is organized like this:

- `generate_mock_data.py` creates synthetic customer and event CSVs
- `raw_customers.csv` is the source customer dataset
- `raw_subscription_events.csv` stores signup, plan change, and churn events
- `saas_project/` contains the dbt project and all transformation logic
- `dbt-env/` is the isolated Python environment used for local dbt execution

## Architecture

The dbt project follows a layered modeling pattern:

1. Staging Layer
   - `stg_customers.sql`
   - `stg_subscription_events.sql`
   - Normalizes raw fields, trims strings, coerces timestamps, and removes incomplete or unusable records.

2. Intermediate Layer
   - `int_months.sql` generates a monthly date spine.
   - `int_customer_months.sql` creates a month-by-customer matrix from the first signup month onward.
   - `int_customer_revenue_by_month.sql` resolves the latest subscription state per customer per month.

3. Mart Layer
   - `fct_mrr.sql` calculates current MRR, prior MRR, and an `mrr_change_category` label to distinguish new, active, upgrade, downgrade, and churn flows.

This is a classic star-schema-adjacent warehouse design where raw inputs are cleaned, then enriched into a business-facing fact model.

## Source Data Model

The pipeline expects two raw files:

### `raw_customers.csv`
Typical columns:

- `customer_id`
- `customer_name`
- `country`
- `created_at`

### `raw_subscription_events.csv`
Typical columns:

- `event_id`
- `customer_id`
- `event_type`
- `plan_name`
- `amount`
- `event_timestamp`

Event types include:

- `signup`
- `plan_change`
- `churn`

The staging layer cleans and standardizes these fields so row-level issues in the raw CSV files do not break downstream logic.

## Data Generation Workflow

The mock data generator is intended to seed the project with realistic but synthetic input data.

### Generate data locally

From the repository root:

```bash
python generate_mock_data.py
```

This script:

- appends new customer records to `raw_customers.csv`
- appends new subscription events to `raw_subscription_events.csv`
- uses Faker to create realistic customer metadata
- emits a mix of signup, upgrade, downgrade, and churn events

## dbt Project Structure

```text
saas_project/
├── dbt_project.yml
├── models/
│   ├── staging/
│   ├── intermediate/
│   └── marts/
├── macros/
├── tests/
├── snapshots/
└── target/
```

## Running the dbt Project

### 1. Activate the Python environment

On Windows PowerShell:

```powershell
cd .\dbt-env\Scripts
.\Activate.ps1
```

or from the repo root:

```powershell
.\dbt-env\Scripts\Activate.ps1
```

### 2. Ensure your dbt profile is configured

The project expects a dbt profile named `saas_project` that points to your warehouse. In this repo, the dbt project is configured with:

- `name: saas_project`
- `profile: saas_project`

The source definitions in `saas_project/models/staging/src_saas.yml` reference:

- database: `saas-mrr-analytics`
- schema: `raw_saas`
- tables:
  - `raw_customers`
  - `raw_subscription_events`

You will typically provide this through your local or CI dbt profile in `~/.dbt/profiles.yml` or an equivalent environment-managed configuration.

### 3. Run the models

Example commands:

```bash
dbt deps
dbt seed
dbt run
dbt test
```

A common execution flow is:

```bash
dbt run --select staging+
dbt run --select intermediate+
dbt run --select marts+
dbt test
```

## Key Transformation Logic

### Staging

The staging layer performs the most important data-quality work:

- trims whitespace from raw strings
- converts ambiguous date strings into valid timestamps
- normalizes event and plan names to lowercase
- backfills missing or malformed values where possible
- deduplicates repeated rows by event/customer identity

### Intermediate Month Spine

`int_months.sql` builds a recurring monthly calendar from January 2024 through the current date. This gives the pipeline a consistent time axis for month-over-month analysis.

`int_customer_months.sql` cross joins each customer with the month spine, producing a complete customer-month timeline that can be joined to event data.

### Customer Revenue by Month

`int_customer_revenue_by_month.sql` uses the latest subscription event per customer per month and carries the active plan and MRR value forward across each month.

This creates a clean historical “current state” view of each customer’s subscription revenue over time.

### Final MRR Fact

The mart model `fct_mrr.sql` computes:

- `current_plan`
- `current_mrr`
- `previous_mrr`
- `mrr_change`
- `mrr_change_category`

The `mrr_change_category` field classifies each month as one of:

- `new`
- `active`
- `upgrade`
- `downgrade`
- `churn`

This makes the output directly consumable for dashboards, executive reporting, or downstream BI layers.

## Expected Outputs

Once the models run successfully, the final MRR data mart is surfaced in the warehouse as an analytics-ready fact view/table. The mart can be used for:

- monthly MRR trend analysis
- cohort-level churn and expansion review
- plan migration analysis
- executive dashboard metrics

## Development Notes

This project is intentionally opinionated around analytics engineering best practices:

- small, focused SQL models
- explicit staging and intermediate layers
- readable source-to-mart lineage
- easy extension for additional metrics such as net revenue retention or customer churn rate

## Known Considerations

- The repo is set up as a dbt project, but the actual warehouse connection details are expected to exist in your dbt profile configuration.
- The `google_creds.json` file in `saas_project/` appears to be part of the environment used to authenticate the warehouse connection.
- The project’s existing SQL is built around BigQuery-style functions such as `SAFE_CAST`, `SAFE.PARSE_TIMESTAMP`, and `TIMESTAMP_SECONDS`, so it is best suited to warehouses with similar SQL behavior.

## Suggested Next Enhancements

You could extend this repository with:

- test coverage for duplicate customer IDs and invalid event types
- snapshots for historical plan assignment changes
- customer-level cohort analysis
- net revenue retention and gross churn metrics
- a BI dashboard layer on top of the mart model

## References

- dbt Documentation: https://docs.getdbt.com/
- BigQuery SQL reference: https://cloud.google.com/bigquery/docs/reference/standard-sql
- Faker Python library: https://faker.readthedocs.io/

