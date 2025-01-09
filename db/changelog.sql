-- Liquibase changelog file

--changeset postgres:1
CREATE TABLE IF NOT EXISTS test (
    id SERIAL PRIMARY KEY,
    value INT NOT NULL
);
GRANT SELECT, UPDATE ON TABLE test TO user_db;
INSERT INTO counter (value) VALUES (0);
--rollback DROP TABLE test;