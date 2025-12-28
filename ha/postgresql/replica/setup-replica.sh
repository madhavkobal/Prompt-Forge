#!/bin/bash
################################################################################
# PostgreSQL Replica Setup Script
################################################################################
#
# This script sets up a PostgreSQL replica (standby) server that replicates
# from the primary server.
#
################################################################################

set -e

echo "Setting up PostgreSQL replica..."

# Wait for primary to be ready
until PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_PRIMARY_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c '\q' 2>/dev/null; do
  echo "Waiting for primary database to be ready..."
  sleep 2
done

echo "Primary database is ready"

# Check if this is the first run (data directory is empty)
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "Setting up replica for the first time..."

    # Remove any existing data
    rm -rf "$PGDATA"/*

    # Create base backup from primary
    echo "Creating base backup from primary..."
    PGPASSWORD="$POSTGRES_REPLICATION_PASSWORD" pg_basebackup \
        -h "$POSTGRES_PRIMARY_HOST" \
        -p "$POSTGRES_PRIMARY_PORT" \
        -U "$POSTGRES_REPLICATION_USER" \
        -D "$PGDATA" \
        -Fp \
        -Xs \
        -P \
        -R

    echo "Base backup completed"

    # Create standby.signal file (for PostgreSQL 12+)
    touch "$PGDATA/standby.signal"

    # Configure recovery settings in postgresql.auto.conf
    cat >> "$PGDATA/postgresql.auto.conf" <<EOF
# Replication settings
primary_conninfo = 'host=$POSTGRES_PRIMARY_HOST port=$POSTGRES_PRIMARY_PORT user=$POSTGRES_REPLICATION_USER password=$POSTGRES_REPLICATION_PASSWORD application_name=replica1'
primary_slot_name = 'replica_slot'
hot_standby = on
max_standby_streaming_delay = 30s
wal_receiver_status_interval = 10s
hot_standby_feedback = on
EOF

    echo "Replica configuration completed"

    # Set proper permissions
    chmod 700 "$PGDATA"

    echo "Replica setup complete. Starting PostgreSQL..."
else
    echo "Replica already initialized. Starting PostgreSQL..."
fi
