#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	-- Creates user and database
	CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';
	CREATE DATABASE ${DB_NAME};
	
	-- Connect to the database
	\c counter_db;

	-- Creates counter table if not exists
	CREATE TABLE IF NOT EXISTS counter (
	    id SERIAL PRIMARY KEY,
	    value INT NOT NULL
	);

	-- Grants rights to $DB_USER
	GRANT SELECT, UPDATE ON TABLE counter TO ${DB_USER};

	-- Inserts initial value into counter table
	INSERT INTO counter (value) VALUES (0)
	ON CONFLICT DO NOTHING; -- Avoids duplicate entries
EOSQL