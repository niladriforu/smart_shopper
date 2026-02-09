# Deployment Plan: Kroger API Data Loader to Databricks

This document outlines the complete plan for creating and deploying a Databricks job that loads data from Kroger APIs (Product and Location) into Databricks tables.

## Overview

**Goal**: Create a Databricks job that:
1. Fetches data from Kroger Product API
2. Fetches data from Kroger Location API
3. Transforms the data into structured format
4. Loads data into Delta tables in Databricks
5. Can be deployed from local machine to Databricks account

## Prerequisites Checklist

- [ ] Databricks workspace access
- [ ] Databricks CLI installed locally
- [ ] Kroger API credentials (Client ID and Client Secret) - working in Postman
- [ ] Python 3.9+ installed locally
- [ ] Git repository (optional but recommended)

---

## Phase 1: Local Development Setup

### Step 1.0: Create Virtual Environment

**Important**: Always use a virtual environment to isolate project dependencies.

1. **Create virtual environment**:
   ```bash
   # Navigate to project directory
   cd /path/to/smart_shopper
   
   # Create virtual environment
   python -m venv venv
   ```
   - This creates a `venv/` directory in your project

2. **Activate virtual environment**:
   ```bash
   # macOS/Linux:
   source venv/bin/activate
   
   # Windows:
   venv\Scripts\activate
   ```
   - You should see `(venv)` in your terminal prompt

3. **Verify activation**:
   ```bash
   which python  # Should point to venv/bin/python
   pip --version # Should use venv's pip
   ```

4. **Add to .gitignore** (if not already):
   - Ensure `venv/` is in `.gitignore` (already included)

**Note**: Always activate the virtual environment before running any pip install commands or working on the project.

### Step 1.1: Install Required Tools

1. **Install Databricks CLI**
   - macOS: `brew install databricks/tap/databricks` (can be installed globally)
   - Windows: `pip install databricks-cli` (install in venv)
   - Verify: `databricks --version`

2. **Install Python build tools** (in virtual environment):
   ```bash
   # Make sure venv is activated first
   pip install build wheel
   ```

### Step 1.2: Configure Databricks CLI

1. Get Databricks workspace URL (format: `https://<workspace-name>.cloud.databricks.com`)
2. Generate Personal Access Token:
   - Databricks workspace → User Settings → Access Tokens → Generate New Token
3. Configure CLI:
   ```bash
   databricks configure --token
   ```
   - Enter workspace URL
   - Enter access token
4. Verify: `databricks workspace ls`

### Step 1.3: Set Up Environment Variables

1. Create `.env` file in project root with:
   ```
   KROGER_API_BASE_URL=https://api.kroger.com
   KROGER_CLIENT_ID=<from_postman>
   KROGER_CLIENT_SECRET=<from_postman>
   DATABRICKS_CATALOG=main
   DATABRICKS_SCHEMA=kroger
   DATABRICKS_PRODUCTS_TABLE=products
   DATABRICKS_LOCATIONS_TABLE=locations
   ```
2. Add `.env` to `.gitignore` (already done)

### Step 1.4: Install Project Dependencies

**After** updating `pyproject.toml` (in Phase 2.1), install dependencies:

```bash
# Make sure virtual environment is activated
source venv/bin/activate  # macOS/Linux
# or: venv\Scripts\activate  # Windows

# Install project and dependencies
pip install -e .

# Or install with dev dependencies
pip install -e ".[dev]"
```

This will install all dependencies listed in `pyproject.toml` into your virtual environment.

---

## Phase 2: Code Structure Development

### Step 2.1: Update Dependencies

**File**: `pyproject.toml`

Add to dependencies:
- `requests>=2.31.0` (for API calls)
- `urllib3>=2.0.0` (for retry logic)
- `pydantic>=2.0.0` (for settings management)
- `python-dotenv>=1.0.0` (for .env file loading)

Keep existing:
- `pyspark>=3.5.0`
- `delta-spark>=3.0.0`
- `pandas>=2.0.0`

**After updating dependencies, install them**:
```bash
# Make sure virtual environment is activated
source venv/bin/activate  # macOS/Linux
# or: venv\Scripts\activate  # Windows

# Install project and dependencies
pip install -e .

# Or install with dev dependencies (for testing tools)
pip install -e ".[dev]"
```

### Step 2.2: Create Configuration Module

**Location**: `src/smart_shopper/config/`

**Files to create**:
1. `__init__.py` - Empty init file
2. `settings.py` - Configuration classes:
   - `KrogerAPISettings` class:
     - `api_base_url` (default: https://api.kroger.com)
     - `client_id` (from env)
     - `client_secret` (from env)
     - `access_token` (optional, auto-fetched if not provided)
   - `DatabricksSettings` class:
     - `catalog` (default: main)
     - `schema` (default: kroger)
     - `products_table` (default: products)
     - `locations_table` (default: locations)
   - Helper functions: `get_kroger_settings()`, `get_databricks_settings()`

**Key Implementation Notes**:
- Use `pydantic.BaseSettings` (or `pydantic_settings.BaseSettings` for v2)
- Load from environment variables
- Support `.env` file

### Step 2.3: Create Kroger API Client

**Location**: `src/smart_shopper/utils/`

**Files to create**:
1. `__init__.py` - Empty init file
2. `kroger_api.py` - `KrogerAPIClient` class:

**Methods needed**:
- `__init__(settings)` - Initialize with settings
- `_authenticate()` - OAuth2 client credentials flow:
  - POST to `/v1/connect/oauth2/token`
  - Use client_id and client_secret
  - Return access_token
- `_get_headers()` - Return headers with Bearer token
- `get_products(**filters)` - Fetch products:
  - Endpoint: `/v1/products`
  - Support pagination (filter.start, filter.limit)
  - Support filters: term, locationId, brand, productId, fulfillment, productIds
  - Handle rate limiting
  - Return list of product dictionaries
- `get_locations(**filters)` - Fetch locations:
  - Endpoint: `/v1/locations`
  - Support filters: zipCode, latLong, chain, limit, radiusInMiles
  - Return list of location dictionaries

**Key Implementation Notes**:
- Use `requests.Session` with retry strategy
- Handle authentication token refresh
- Implement rate limiting (sleep between requests)
- Error handling for API failures

### Step 2.4: Create Data Transformation Module

**Location**: `src/smart_shopper/transformations/`

**Files to create**:
1. `__init__.py` - Empty init file
2. `kroger_data.py` - Transformation functions:

**Functions needed**:
- `transform_products_data(spark, products)`:
  - Input: SparkSession, list of product dicts from API
  - Flatten nested structure (items, images, aisleLocations, etc.)
  - Create DataFrame with schema:
    - product_id, item_id, upc, brand, description, size
    - image, aisle, department, category
    - price, promo_price, sold_by
    - fetch_timestamp
  - Return Spark DataFrame
- `transform_locations_data(spark, locations)`:
  - Input: SparkSession, list of location dicts from API
  - Flatten nested structure (address, geolocation, hours)
  - Create DataFrame with schema:
    - location_id, chain, name
    - address_line1, address_line2, city, state, zip_code
    - latitude, longitude
    - phone, fax
    - monday_open, monday_close, ... (all days)
    - fetch_timestamp
  - Return Spark DataFrame
- Helper functions: `_get_products_schema()`, `_get_locations_schema()`

**Key Implementation Notes**:
- Use PySpark StructType for schemas
- Handle missing/null fields gracefully
- Flatten nested JSON structures
- Add fetch_timestamp column

### Step 2.5: Create Job Entry Point

**Location**: `src/smart_shopper/jobs/`

**Files to create**:
1. `__init__.py` - Empty init file
2. `kroger_data_loader.py` - Main job:

**Functions needed**:
- `load_kroger_data(load_products=True, load_locations=True, products_filter=None, locations_filter=None)`:
  - Initialize SparkSession
  - Get settings (Kroger and Databricks)
  - Initialize KrogerAPIClient
  - Get current timestamp
  - If load_products:
    - Call `api_client.get_products(**products_filter)`
    - Transform with `transform_products_data()`
    - Add fetch_timestamp column
    - Write to Delta table: `{catalog}.{schema}.{products_table}`
    - Use `mode("append")` for incremental loads
  - If load_locations:
    - Call `api_client.get_locations(**locations_filter)`
    - Transform with `transform_locations_data()`
    - Add fetch_timestamp column
    - Write to Delta table: `{catalog}.{schema}.{locations_table}`
    - Use `mode("append")` for incremental loads
  - Handle errors and log progress
- `main()` - Entry point that calls `load_kroger_data()`

**Key Implementation Notes**:
- Use `SparkSession.builder.appName("KrogerDataLoader").getOrCreate()`
- Write to Delta format: `.format("delta").mode("append").saveAsTable()`
- Add proper error handling and logging
- Stop Spark session in finally block

---

## Phase 3: Databricks Setup

### Step 3.1: Create Tables in Databricks

**Action**: Run SQL in Databricks notebook or SQL editor

1. **Create catalog and schema**:
   ```sql
   CREATE CATALOG IF NOT EXISTS main;
   USE CATALOG main;
   CREATE SCHEMA IF NOT EXISTS kroger;
   USE SCHEMA kroger;
   ```

2. **Create products table**:
   ```sql
   CREATE TABLE IF NOT EXISTS products (
       product_id STRING,
       item_id STRING,
       upc STRING,
       brand STRING,
       description STRING,
       size STRING,
       image STRING,
       aisle STRING,
       department STRING,
       category STRING,
       price DOUBLE,
       promo_price DOUBLE,
       sold_by STRING,
       fetch_timestamp STRING
   ) USING DELTA;
   ```

3. **Create locations table**:
   ```sql
   CREATE TABLE IF NOT EXISTS locations (
       location_id STRING,
       chain STRING,
       name STRING,
       address_line1 STRING,
       address_line2 STRING,
       city STRING,
       state STRING,
       zip_code STRING,
       latitude DOUBLE,
       longitude DOUBLE,
       phone STRING,
       fax STRING,
       monday_open STRING,
       monday_close STRING,
       tuesday_open STRING,
       tuesday_close STRING,
       wednesday_open STRING,
       wednesday_close STRING,
       thursday_open STRING,
       thursday_close STRING,
       friday_open STRING,
       friday_close STRING,
       saturday_open STRING,
       saturday_close STRING,
       sunday_open STRING,
       sunday_close STRING,
       fetch_timestamp STRING
   ) USING DELTA;
   ```

### Step 3.2: Set Up Databricks Secrets (Recommended for Production)

**Action**: Use Databricks CLI or UI

1. **Create secret scope**:
   ```bash
   databricks secrets create-scope --scope kroger-api
   ```

2. **Add secrets**:
   ```bash
   databricks secrets put --scope kroger-api --key client_id
   # Paste client_id when prompted
   
   databricks secrets put --scope kroger-api --key client_secret
   # Paste client_secret when prompted
   ```

3. **Update code** (optional - can use environment variables instead):
   - Modify `settings.py` to read from Databricks secrets using `dbutils.secrets.get()`
   - Or keep using environment variables (simpler for initial setup)

---

## Phase 4: Build and Package

### Step 4.1: Build Python Wheel

**Action**: Run locally (with virtual environment activated)

```bash
# Activate virtual environment first
source venv/bin/activate  # macOS/Linux
# or: venv\Scripts\activate  # Windows

# Install build tools (if not already installed)
pip install build wheel

# Build the package
python -m build

# Verify output
ls dist/
# Should see: smart_shopper-0.1.0-py3-none-any.whl
```

### Step 4.2: Test Locally (Optional)

**Action**: Test the code locally if you have Spark installed (with virtual environment activated)

```bash
# Activate virtual environment first
source venv/bin/activate  # macOS/Linux
# or: venv\Scripts\activate  # Windows

# Install in development mode
pip install -e .

# Test API client
python -c "from smart_shopper.utils.kroger_api import KrogerAPIClient; client = KrogerAPIClient(); print(client.get_locations(filter_zip_code='45202')[:1])"
```

---

## Phase 5: Deployment Options

Choose one deployment method:

### Option A: Databricks Repos (Recommended for Development)

**Steps**:
1. Push code to Git repository (GitHub, GitLab, etc.)
2. In Databricks workspace:
   - Go to Repos → Add Repo
   - Enter repository URL
   - Select branch
   - Click Create Repo
3. Install package in Databricks:
   - Open notebook
   - Run: `%pip install -e /Workspace/Repos/your-username/smart_shopper`
4. Set environment variables:
   - Cluster → Advanced Options → Environment Variables
   - Add: `KROGER_CLIENT_ID`, `KROGER_CLIENT_SECRET`, etc.

**Job Configuration**:
- Type: Python script
- Path: `/Workspace/Repos/your-username/smart_shopper/src/smart_shopper/jobs/kroger_data_loader.py`
- Cluster: Select existing or create new

### Option B: Upload Wheel to DBFS

**Steps**:
1. Upload wheel file:
   ```bash
   databricks fs mkdirs dbfs:/FileStore/jobs/smart_shopper/dist
   databricks fs cp dist/smart_shopper-0.1.0-py3-none-any.whl dbfs:/FileStore/jobs/smart_shopper/dist/
   ```
2. Create workflow JSON file (see Step 5.3)
3. Deploy workflow using CLI or UI

### Option C: Direct File Upload

**Steps**:
1. Upload source files:
   ```bash
   databricks workspace import_dir src/ /Workspace/your-path/smart_shopper/src --overwrite
   ```
2. Install dependencies in cluster
3. Configure job to run Python file

---

## Phase 6: Create and Deploy Workflow

### Step 6.1: Create Workflow Configuration

**Location**: `databricks/workflows/kroger_data_loader.json`

**Configuration structure**:
```json
{
  "name": "kroger_data_loader",
  "tasks": [{
    "task_key": "load_kroger_data",
    "spark_python_task": {
      "python_file": "/Workspace/Repos/.../kroger_data_loader.py",
      "parameters": []
    },
    "existing_cluster_id": "YOUR_CLUSTER_ID"
  }],
  "schedule": {
    "quartz_cron_expression": "0 0 * * * ?",
    "timezone_id": "America/New_York",
    "pause_status": "UNPAUSED"
  }
}
```

**Or for wheel-based deployment**:
```json
{
  "tasks": [{
    "python_wheel_task": {
      "package_name": "smart_shopper",
      "entry_point": "jobs.kroger_data_loader.main",
      "parameters": []
    },
    "libraries": [{
      "whl": "dbfs:/FileStore/jobs/smart_shopper/dist/smart_shopper-0.1.0-py3-none-any.whl"
    }]
  }]
}
```

### Step 6.2: Deploy Workflow

**Method 1: Using Databricks UI** (Easiest)
1. Go to Workflows → Create
2. Configure:
   - Name: `kroger_data_loader`
   - Type: Python script
   - Path: Path to your Python file
   - Cluster: Select cluster
   - Environment Variables: Add Kroger credentials
3. Set schedule (optional)
4. Save and Run

**Method 2: Using Databricks CLI**
```bash
# Update JSON file with your cluster ID
# Then create job
databricks jobs create --json-file databricks/workflows/kroger_data_loader.json
```

**Method 3: Using Databricks API**
```bash
curl -X POST \
  https://<workspace-url>/api/2.1/jobs/create \
  -H 'Authorization: Bearer <token>' \
  -H 'Content-Type: application/json' \
  -d @databricks/workflows/kroger_data_loader.json
```

### Step 6.3: Configure Environment Variables

**In Databricks Job/Cluster**:
- `KROGER_CLIENT_ID`: Your client ID
- `KROGER_CLIENT_SECRET`: Your client secret
- `DATABRICKS_CATALOG`: main (or your catalog)
- `DATABRICKS_SCHEMA`: kroger (or your schema)

**Or use Databricks Secrets**:
- Reference secrets in code: `dbutils.secrets.get(scope="kroger-api", key="client_id")`

---

## Phase 7: Testing and Validation

### Step 7.1: Run Job Manually

1. **In Databricks UI**:
   - Go to Workflows → Your Job → Run Now

2. **Or via CLI**:
   ```bash
   databricks jobs run-now --job-id <job-id>
   ```

3. **Monitor execution**:
   - View run details
   - Check logs for errors
   - Verify data loaded

### Step 7.2: Verify Data

**Run in Databricks notebook**:
```python
# Check products
spark.sql("SELECT COUNT(*) as product_count FROM main.kroger.products").show()
spark.sql("SELECT * FROM main.kroger.products LIMIT 10").show()

# Check locations
spark.sql("SELECT COUNT(*) as location_count FROM main.kroger.locations").show()
spark.sql("SELECT * FROM main.kroger.locations LIMIT 10").show()
```

### Step 7.3: Schedule Job (Optional)

1. **In Databricks UI**:
   - Workflows → Your Job → Settings → Schedule
   - Set cron expression (e.g., `0 0 * * * ?` for daily at midnight)

2. **Or update via CLI**:
   ```bash
   databricks jobs update --job-id <job-id> --json-file updated_workflow.json
   ```

---

## Phase 8: Maintenance and Updates

### Updating the Job

1. **Make code changes locally**
2. **If using Repos**: Push to Git, Databricks auto-syncs
3. **If using wheel**: 
   - Rebuild: `python -m build`
   - Re-upload: `databricks fs cp dist/... --overwrite`
4. **Restart job** or wait for next scheduled run

### Monitoring

- Set up email notifications for job failures
- Monitor job run history
- Check data quality regularly
- Review API rate limits and usage

---

## Summary Checklist

**Local Setup**:
- [ ] Create and activate virtual environment
- [ ] Install Databricks CLI
- [ ] Configure CLI with workspace and token
- [ ] Create `.env` file with Kroger credentials
- [ ] Update `pyproject.toml` with dependencies
- [ ] Install project dependencies in virtual environment

**Code Development**:
- [ ] Create config module with settings classes
- [ ] Create Kroger API client with authentication
- [ ] Create data transformation functions
- [ ] Create job entry point
- [ ] Test API client locally (optional)

**Databricks Setup**:
- [ ] Create catalog and schema
- [ ] Create products and locations tables
- [ ] Set up Databricks secrets (optional)

**Build and Deploy**:
- [ ] Build Python wheel package
- [ ] Choose deployment method (Repos/Wheel/Upload)
- [ ] Deploy code to Databricks
- [ ] Create and configure workflow
- [ ] Set environment variables in cluster/job

**Testing**:
- [ ] Run job manually
- [ ] Verify data in tables
- [ ] Set up schedule (optional)
- [ ] Configure monitoring/notifications

---

## Troubleshooting Guide

**Common Issues**:

1. **Authentication Errors**:
   - Verify Kroger API credentials
   - Check token expiration
   - Review API documentation for correct endpoints

2. **Import Errors**:
   - Ensure package installed in cluster
   - Check Python path in job configuration
   - Verify all dependencies in `pyproject.toml`

3. **Table Not Found**:
   - Run table creation SQL
   - Verify catalog and schema names match settings
   - Check permissions

4. **Permission Errors**:
   - Verify cluster permissions
   - Check table write permissions
   - Review Databricks access controls

**Getting Help**:
- Check Databricks job logs
- Review API response in Postman
- Test API client locally
- Use `databricks runs get-output --run-id <run-id>` for CLI logs

---

## Next Steps After Deployment

- [ ] Set up data quality checks
- [ ] Implement incremental loading logic
- [ ] Add error handling and retry mechanisms
- [ ] Set up data retention policies
- [ ] Create dashboards for monitoring
- [ ] Document API usage and rate limits
- [ ] Plan for scaling (handle large datasets)

