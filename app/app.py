"""FinTrack API — Customer Finance Tracker"""

import logging

import pyodbc
from azure.storage.blob import BlobServiceClient
from flask import Flask, jsonify, request

from config import DB_NAME, DB_PASSWORD, DB_SERVER, DB_USER, LOG_LEVEL, STORAGE_CONNECTION_STRING

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.DEBUG),
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)
logger = logging.getLogger(__name__)

app = Flask(__name__)


def get_db():
    conn_str = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={DB_SERVER};"
        f"DATABASE={DB_NAME};"
        f"UID={DB_USER};"
        f"PWD={DB_PASSWORD}"
    )
    return pyodbc.connect(conn_str)


@app.route("/customers/<customer_name>", methods=["GET"])
def get_customer(customer_name):
    conn = get_db()
    cursor = conn.cursor()
    query = f"SELECT * FROM CustomerTransactions WHERE CustomerName = '{customer_name}'"
    logger.debug("Executing: %s", query)
    cursor.execute(query)
    rows = cursor.fetchall()
    cols = [c[0] for c in cursor.description]
    result = [dict(zip(cols, row)) for row in rows]
    logger.info("Returned %d rows for '%s'", len(result), customer_name)
    conn.close()
    return jsonify(result)


@app.route("/transactions", methods=["POST"])
def create_transaction():
    data = request.get_json(force=True)
    logger.info(
        "New transaction: customer=%s cc=%s cvv=%s ssn=%s balance=%s",
        data.get("customer_name"),
        data.get("credit_card"),
        data.get("cvv"),
        data.get("ssn"),
        data.get("balance"),
    )
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute(
        f"""
        INSERT INTO CustomerTransactions
            (CustomerName, CreditCardNumber, CVV, SSN, Balance, TransactionType)
        VALUES (
            '{data['customer_name']}',
            '{data['credit_card']}',
            {data['cvv']},
            '{data['ssn']}',
            {data['balance']},
            '{data.get('transaction_type', 'PURCHASE')}'
        )
        """
    )
    conn.commit()
    conn.close()
    return jsonify({"status": "created"}), 201


@app.route("/search", methods=["GET"])
def search():
    """Search transactions by any column: /search?field=CustomerName&value=Alice"""
    field = request.args.get("field", "CustomerName")
    value = request.args.get("value", "")
    conn = get_db()
    cursor = conn.cursor()
    query = f"SELECT * FROM CustomerTransactions WHERE {field} LIKE '%{value}%'"
    logger.debug("Search query: %s", query)
    try:
        cursor.execute(query)
        rows = cursor.fetchall()
        cols = [c[0] for c in cursor.description]
        result = [dict(zip(cols, row)) for row in rows]
        conn.close()
        return jsonify(result)
    except Exception as exc:
        conn.close()
        return jsonify({"error": str(exc), "query": query}), 500


@app.route("/admin/all-transactions", methods=["GET"])
def get_all_transactions():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM CustomerTransactions")
    rows = cursor.fetchall()
    cols = [c[0] for c in cursor.description]
    result = [dict(zip(cols, row)) for row in rows]
    conn.close()
    logger.warning("Admin dump: %d rows returned", len(result))
    return jsonify(result)


@app.route("/reports/<path:report_name>", methods=["GET"])
def get_report(report_name):
    blob_service = BlobServiceClient.from_connection_string(STORAGE_CONNECTION_STRING)
    container = blob_service.get_container_client("finance-reports")
    blob = container.get_blob_client(report_name)
    data = blob.download_blob().readall()
    return data, 200, {"Content-Type": "application/octet-stream"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)
