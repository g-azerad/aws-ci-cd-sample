FROM liquibase/liquibase:latest

USER root

RUN mkdir -p /home/liquibase/.ssh && \
    chown -R liquibase:liquibase /home/liquibase && \
    chmod 700 /home/liquibase/.ssh