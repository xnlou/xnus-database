#!/bin/bash

# Global variables
SESSION_UUID=$(uuidgen)
LOG_COUNTER=0
START_TIME=$(date +%s)
LAST_LOG_TIME=$START_TIME
DB_CONN=""
PROCESS_TYPE="default"

# Function to setup logging
setup_logging() {
    local log_file_path="$1"
    local db_params="$2"  # Format: "host=localhost port=5432 user=youruser password=yourpass dbname=yourdb"

    # Ensure the directory exists
    mkdir -p "$(dirname "$log_file_path")"

    # Reset counters and times
    LOG_COUNTER=0
    START_TIME=$(date +%s)
    LAST_LOG_TIME=$START_TIME

    # Set up database connection if provided
    if [ -n "$db_params" ]; then
        DB_CONN="$db_params"
        # Create table if it doesn't exist (you might need to adjust this based on your actual permissions and setup)
        psql $DB_CONN -c "CREATE TABLE IF NOT EXISTS logs (
            id SERIAL PRIMARY KEY,
            timestamp TIMESTAMP,
            counter INTEGER,
            uuid TEXT,
            process_type TEXT,
            step_runtime REAL,
            total_runtime REAL,
            message TEXT,
            user TEXT);"
    fi

    echo "Logging setup complete. UUID: $SESSION_UUID"
}

# Function to log messages
log_etl_event() {
    local message="$1"
    local process_type="${2:-$PROCESS_TYPE}"
    local log_to_db="${3:-false}"

    ((LOG_COUNTER++))
    local CURRENT_TIME=$(date +%s)
    local TOTAL_RUNTIME=$(echo "scale=2; ($CURRENT_TIME - $START_TIME) / 60" | bc)
    local STEP_RUNTIME=$(echo "scale=2; ($CURRENT_TIME - $LAST_LOG_TIME) / 60" | bc)
    local CURRENT_USER=$(whoami)

    # Format the log message
    local FORMATTED_MESSAGE="Counter: $LOG_COUNTER - UUID: $SESSION_UUID - Process Type: $process_type - Step Runtime: $STEP_RUNTIME min - Total Runtime: $TOTAL_RUNTIME min - $message - User: $CURRENT_USER"

    # Log to file
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $FORMATTED_MESSAGE" >> "$log_file_path"

    # Log to database if specified
    if [ "$log_to_db" = true ] && [ -n "$DB_CONN" ]; then
        psql $DB_CONN -c "INSERT INTO logs (timestamp, counter, uuid, process_type, step_runtime, total_runtime, message, user) VALUES (
            current_timestamp, 
            $LOG_COUNTER, 
            '$SESSION_UUID', 
            '$process_type', 
            $STEP_RUNTIME, 
            $TOTAL_RUNTIME, 
            '$message', 
            '$CURRENT_USER');"
    fi

    LAST_LOG_TIME=$CURRENT_TIME
}

# Function to close logging
close_log() {
    if [ -n "$DB_CONN" ]; then
        # Note: Since we're using psql, there's no need to explicitly close the connection
        echo "Database logging session closed."
    fi
    echo "Logging session ended."
}

# Example usage
log_file_path="/home/xnus01/projects/etl_hub/bash_etl.log"
db_params="host=localhost port=5432 user=youruser password=yourpass dbname=yourdb"

setup_logging "$log_file_path" "$db_params"
log_etl_event "ETL process started" "ETL" true
log_etl_event "Extracting data from source"
log_etl_event "Transforming data"
log_etl_event "Loading data into PostgreSQL" "ETL" true
close_log