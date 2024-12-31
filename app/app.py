import os
from flask import Flask, jsonify
import psycopg2
from psycopg2.extras import RealDictCursor
import awsgi2

app = Flask(__name__)

db_config = {
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD'),
    'host': os.getenv('DB_HOST'),
    'port': os.getenv('DB_PORT', '5432'),
    'dbname': os.getenv('DB_NAME')
}

def get_db_connection():
    return psycopg2.connect(**db_config)
    
def set_db_conn_cursor():
    """Sets the database connection and the cursor."""
    try:
        conn = get_db_connection()
        # cursor_factory=RealDictCursor
        cursor = conn.cursor()
    except Exception as e:
        return None, None, False
    return conn, cursor, True

@app.route('/counter', methods=['GET'])
def get_counter():
    """Fetch the current value of the counter."""
    conn, cursor, status = set_db_conn_cursor()
    if not status:
        return jsonify({"error": "Database connection failure"}), 500
    try:
        cursor.execute('SELECT value FROM counter WHERE id = 1')
        counter = cursor.fetchone()
    except Exception as e:
        conn.rollback()
        return jsonify({"error": "Counter select query failure"}), 500
    finally:
        cursor.close()
        conn.close()
    if counter:
        return jsonify({"value": counter[0]}), 200
    return jsonify({"error": "Counter not found"}), 404

@app.route('/counter/increment', methods=['PUT'])
def increment_counter():
    """Increment the counter by 1."""
    conn, cursor, status = set_db_conn_cursor()
    if not status:
        return jsonify({"error": "Database connection failure"}), 500
    try:
        cursor.execute('UPDATE counter SET value = value + 1 WHERE id = 1 RETURNING value')
        updated_value = cursor.fetchone()[0]
        conn.commit()
    except Exception as e:
        conn.rollback()
        return jsonify({"error": "Counter increment query failure"}), 500
    finally:
        cursor.close()
        conn.close()
    return jsonify({"value": updated_value}), 200

@app.route('/counter/decrement', methods=['PUT'])
def decrement_counter():
    """Decrement the counter by 1."""
    conn, cursor, status = set_db_conn_cursor()
    if not status:
        return jsonify({"error": "Database connection failure"}), 500
    try:
        cursor.execute('''
            UPDATE counter
            SET value = CASE WHEN value > 0 THEN value - 1 ELSE value END
            WHERE id = 1
            RETURNING value;
        ''')
        updated_value = cursor.fetchone()[0]
        conn.commit()
    except Exception as e:
        conn.rollback()
        return jsonify({"error": "Counter decrement query failure"}), 500
    finally:
        cursor.close()
        conn.close()
    return jsonify({"value": updated_value}), 200

def handler(event, context):
    """Lambda handler when executed in an AWS Lambda function"""
    return awsgi2.response(app, event, context)

if __name__ == '__main__':
    """Local executor"""
    # Checking if debug mode is enabled
    if os.getenv('DEBUG_MODE') == "true":
        debug_mode = True
    else:
        debug_mode = False
    app.run(host="0.0.0.0", debug=debug_mode)