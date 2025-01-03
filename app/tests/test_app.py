import unittest
from unittest.mock import patch, MagicMock
from app import app

class TestApp(unittest.TestCase):

    def setUp(self):
        self.client = app.test_client()  # Creates a Flask client for the tests
        self.client.testing = True

    @patch('app.get_db_connection')
    def test_get_counter_success(self, mock_get_db_connection):
        # Mock db connection
        mock_conn = MagicMock()
        mock_cursor = mock_conn.cursor.return_value
        mock_cursor.fetchone.return_value = [42]  # Simulates a counter value

        mock_get_db_connection.return_value = mock_conn

        # Call the API
        response = self.client.get('/counter')
        print(f"\nResponse status code: {response.status_code}")
        print(f"Response JSON: {response.json}")

        # Assertions
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json, {"value": 42})
        mock_cursor.execute.assert_called_once_with('SELECT value FROM counter WHERE id = 1')

    @patch('app.get_db_connection')
    def test_get_counter_not_found(self, mock_get_db_connection):
        # Simulates an empty database answer
        mock_conn = MagicMock()
        mock_cursor = mock_conn.cursor.return_value
        mock_cursor.fetchone.return_value = None

        mock_get_db_connection.return_value = mock_conn

        # Call the API
        response = self.client.get('/counter')
        print(f"\nResponse status code: {response.status_code}")
        print(f"Response JSON: {response.json}")

        # Assertions
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json, {"error": "Counter not found"})

    @patch('app.get_db_connection')
    def test_increment_counter_success(self, mock_get_db_connection):
        # Mock to increment the counter
        mock_conn = MagicMock()
        mock_cursor = mock_conn.cursor.return_value
        mock_cursor.fetchone.return_value = [43]  # Simulates an incremented value

        mock_get_db_connection.return_value = mock_conn

        # Call the API
        response = self.client.put('/counter/increment')
        print(f"\nResponse status code: {response.status_code}")
        print(f"Response JSON: {response.json}")

        # Assertions
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json, {"value": 43})
        mock_cursor.execute.assert_called_once_with(
            'UPDATE counter SET value = value + 1 WHERE id = 1 RETURNING value'
        )

    @patch('app.get_db_connection')
    def test_reset_counter_success(self, mock_get_db_connection):
        # Mock to reset the counter
        mock_conn = MagicMock()
        mock_cursor = mock_conn.cursor.return_value
        mock_cursor.fetchone.return_value = [0]  # Simulates a reseted value

        mock_get_db_connection.return_value = mock_conn

        # Call the API
        response = self.client.put('/counter/reset')
        print(f"\nResponse status code: {response.status_code}")
        print(f"Response JSON: {response.json}")

        # Assertions
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json, {"value": 0})
        mock_cursor.execute.assert_called_once_with(
            'UPDATE counter SET value = 0 WHERE id = 1 RETURNING value'
        )

    @patch('app.get_db_connection')
    def test_database_connection_failure(self, mock_get_db_connection):
        # Simulates an error connecting to the database
        mock_get_db_connection.side_effect = Exception("Database connection error")

        # Call the API
        response = self.client.get('/counter')
        print(f"\nResponse status code: {response.status_code}")
        print(f"Response JSON: {response.json}")

        # Assertions
        self.assertEqual(response.status_code, 500)
        self.assertEqual(response.json, {"error": "Database connection failure"})

if __name__ == '__main__':
    unittest.main()
