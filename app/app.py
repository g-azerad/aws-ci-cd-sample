"""
This module sets up an API with a counter relying on a PostgreSQL database
"""

import os
import sys
import boto3
from flask import Flask, jsonify
import psycopg2
import awsgi2

app = Flask(__name__)

def get_secret(debug_mode):
    """Retrieves the password from AWS Secrets manager or get IAM token if not provided."""
    # Get IAM token if IAM_AUTH environment variable is set
    region_name = os.getenv('AWS_REGION', 'eu-west-3')
    session = boto3.session.Session()
    iam_auth = os.getenv('IAM_AUTH', 'disable')
    if debug_mode:
        print("DEBUG - IAM authentication state : "+ iam_auth)
    if iam_auth != 'disable':
        try:
            token = session.client('rds').generate_db_auth_token(
                DBHostname=db_config['host'],
                Port=db_config['port'],
                DBUsername=db_config['user'],
                Region=region_name)
            if debug_mode:
                print("DEBUG - Password retrieved as IAM token : " + token)
            if token:
                return token
        except Exception as e:
            print("An exception has been raised during IAM token retrieval : "+ e)
            return False
    
    # Then get password from AWS Secrets manager
    secrets_client = session.client(service_name="secretsmanager", region_name=region_name)
    secret_name = os.getenv('DB_USER_SECRET')
    if secret_name:
        if debug_mode:
            print("DEBUG - Getting secret "+ secret_name + ", region "+ region_name)
        try:
            secret_value_response = secrets_client.get_secret_value(SecretId=secret_name)
            if secret_value_response:
                if secret_value_response['SecretString']:
                    return secret_value_response['SecretString']
        except Exception as e:
            print("An exception has been raised during secret resolution : "+ e)
            return False
    
    # Else, test if a password is directly provided
    if os.getenv('DB_PASSWORD'):
        if debug_mode:
            print("DEBUG - Password retrieved from DB_PASSWORD environment variable")
        return os.getenv('DB_PASSWORD')
    # If nothing is found, return False
    return False

# Database configuration dictionary required by psycopg2
db_config = {
    'user': os.getenv('DB_USER'),
    'host': os.getenv('DB_HOST'),
    'port': os.getenv('DB_PORT', '5432'),
    'dbname': os.getenv('DB_NAME'),
    'password': ""
}
# Password parameter is set from get_secret function
debug_mode = bool(os.getenv('DEBUG_MODE') == "true")
password = get_secret(debug_mode)
if not password:
    raise RuntimeError("Password retrieval failure: Unable to start the application.")
db_config['password'] = password

# Add SSL configuration if SSL_MODE is defined
ssl_mode = os.getenv('SSL_MODE', 'disable')
if ssl_mode != 'disable':
    db_config['sslmode'] = ssl_mode
    db_config['sslrootcert'] = os.getenv('SSL_ROOT_CERT', '/etc/ssl/certs/eu-west-3-bundle.pem')

def get_db_connection():
    """Gets the connection to the PostgreSQL database defined by db_config variable."""
    return psycopg2.connect(**db_config)

def set_db_conn_cursor():
    """Sets the database connection and the cursor."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
    except psycopg2.Error as e:
        print(e, file=sys.stderr)
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
    except psycopg2.Error as e:
        print(e, file=sys.stderr)
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
    except psycopg2.Error as e:
        print(e, file=sys.stderr)
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
    except psycopg2.Error as e:
        print(e, file=sys.stderr)
        conn.rollback()
        return jsonify({"error": "Counter decrement query failure"}), 500
    finally:
        cursor.close()
        conn.close()
    return jsonify({"value": updated_value}), 200

@app.route('/counter/reset', methods=['PUT'])
def reset_counter():
    """Reset the counter."""
    conn, cursor, status = set_db_conn_cursor()
    if not status:
        return jsonify({"error": "Database connection failure"}), 500
    try:
        cursor.execute('UPDATE counter SET value = 0 WHERE id = 1 RETURNING value')
        updated_value = cursor.fetchone()[0]
        conn.commit()
    except psycopg2.Error as e:
        print(e, file=sys.stderr)
        conn.rollback()
        return jsonify({"error": "Counter reset query failure"}), 500
    finally:
        cursor.close()
        conn.close()
    return jsonify({"value": updated_value}), 200

@app.route('/healthcheck', methods=['GET'])
def set_healthcheck():
    """Provide an answer to healthcheck requests"""
    return jsonify({"result": "OK"}), 200

def handler(event, context):
    """Lambda handler when executed in an AWS Lambda function"""
    return awsgi2.response(app, event, context)

if __name__ == '__main__':
    # Local executor
    # Setting Flask debug mode from environment variable
    debug_mode = bool(os.getenv('DEBUG_MODE') == "true")
    # Setting Flask port from environment variable
    flask_port = os.getenv('FLASK_PORT', '5000')
    app.run(host="0.0.0.0", port=flask_port, debug=debug_mode)
