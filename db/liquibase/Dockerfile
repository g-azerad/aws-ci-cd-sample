FROM liquibase/liquibase:latest

USER root

RUN apt-get update && apt-get install -y --no-install-recommends openssh-client && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /home/liquibase/.ssh && \
    chown -R liquibase:liquibase /home/liquibase && \
    chmod 700 /home/liquibase/.ssh

USER liquibase
WORKDIR /home/liquibase