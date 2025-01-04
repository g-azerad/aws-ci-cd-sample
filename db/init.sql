-- Creates database
CREATE DATABASE counter_db;

-- Connect to the database
\c counter_db;

-- Creates counter table if not exists
CREATE TABLE IF NOT EXISTS counter (
    id SERIAL PRIMARY KEY,
    value INT NOT NULL
);

-- Creates user and grants rights
\set db_password  'password'
CREATE ROLE user_db WITH LOGIN PASSWORD :'db_password';
GRANT SELECT, UPDATE ON TABLE counter TO user_db;

-- Inserts initial value into counter table
INSERT INTO counter (value) VALUES (0)
ON CONFLICT DO NOTHING; -- Avoids duplicate entries

-- Creates IAM user for AWS
CREATE ROLE iam_user WITH LOGIN;
GRANT rds_iam TO iam_user;
