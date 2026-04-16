# FinTrack API

REST API for the FinTrack customer finance tracking platform. Stores and retrieves
customer transactions backed by Azure SQL Database and Azure Blob Storage.

## Prerequisites

- Python 3.10+
- Azure CLI (`az login`)
- [ODBC Driver 18 for SQL Server](https://aka.ms/downloadodbc)
- `jq`

**macOS:** `brew install microsoft/mssql-release/msodbcsql18 jq`
**Linux:** Follow the [ODBC docs](https://aka.ms/downloadodbc) for your distro, install `jq` via your package manager.
**Windows:** Download the ODBC driver MSI; use Git Bash or WSL to run the deploy script.

## Deploy

```bash
az login
cd infra
chmod +x deploy.sh
bash deploy.sh
```

Initialise the database (use the server name printed by the deploy script):

```bash
sqlcmd -S <server> -d finance-db -U sqladmin -P 'Password123!' -i database/schema.sql
sqlcmd -S <server> -d finance-db -U sqladmin -P 'Password123!' -i database/seed.sql
```

Or use the Query Editor in the Azure Portal.

## Run

```bash
cd app
pip install -r requirements.txt
python app.py
```

API available at `http://localhost:5001`.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/customers/<name>` | Transactions for a customer |
| GET | `/search?field=X&value=Y` | Search any column |
| GET | `/admin/all-transactions` | All transactions |
| POST | `/transactions` | Create a transaction |
| GET | `/reports/<file>` | Download a report from blob storage |

## Cleanup

```bash
az group delete --name rg-fintrack --yes --no-wait
```
