FROM liquibase/liquibase:latest

USER root

RUN apt-get update && apt-get install -y --no-install-recommends openssh-client && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /home/liquibase/.ssh && \
    chown -R liquibase:liquibase /home/liquibase && \
    chmod 700 /home/liquibase/.ssh

USER liquibase
WORKDIR /home/liquibase

COPY --chown=liquibase:liquibase ssh/config /home/liquibase/.ssh/
COPY --chown=liquibase:liquibase ssh/known_hosts /home/liquibase/.ssh/
COPY --chown=liquibase:liquibase --chmod=600 ssh/id_aws_ed25519_prod /home/liquibase/.ssh/