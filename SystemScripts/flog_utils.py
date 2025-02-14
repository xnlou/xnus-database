import logging
import uuid
import time
import os
import psycopg2

session_uuid = str(uuid.uuid4())
log_counter = 0
start_time = None
last_log_time = None
db_conn = None
process_type = "default"  # Default process type, can be changed or set dynamically

def setup_logging(log_file_path, db_params=None):
    global session_uuid, log_counter, start_time, last_log_time, db_conn
    
    # Reset counters and times
    log_counter = 0
    start_time = time.time()
    last_log_time = start_time
    
    # Ensure the directory exists
    os.makedirs(os.path.dirname(log_file_path), exist_ok=True)
    
    # Setup logging to use this file handler
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    
    # Create file handler which logs even debug messages
    fh = logging.FileHandler(log_file_path, mode='a')
    formatter = logging.Formatter('%(asctime)s - %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
    fh.setFormatter(formatter)
    
    # Add the handlers to the logger
    logger.addHandler(fh)
    
    # Setup database if required
    if db_params:
        try:
            db_conn = psycopg2.connect(**db_params)
            cursor = db_conn.cursor()
            cursor.execute('''CREATE TABLE IF NOT EXISTS logs
                              (id SERIAL PRIMARY KEY,
                              timestamp TIMESTAMP,
                              counter INTEGER,
                              uuid TEXT,
                              process_type TEXT,
                              step_runtime REAL,
                              total_runtime REAL,
                              message TEXT,
                              user TEXT)''')
            db_conn.commit()
        except psycopg2.Error as e:
            print(f"An error occurred while connecting to the database: {e}")

    return session_uuid

def fLog(message, process_type="default", log_to_db=False):
    global log_counter, last_log_time, db_conn
    
    try:
        log_counter += 1  # Increment the counter for each log entry
        
        current_time = time.time()
        total_runtime = current_time - start_time
        step_runtime = current_time - last_log_time
        
        # Get the current user
        current_user = os.getlogin()  # This gets the username of the logged-in user
        
        # Format the log message with all the required information including the user and process type
        formatted_message = f"Counter: {log_counter} - UUID: {session_uuid} - Process Type: {process_type} - Step Runtime: {step_runtime:.2f} - Total Runtime: {total_runtime:.2f} - {message} - User: {current_user}"
        
        last_log_time = current_time
        
        # Log using Python's logging for file logging
        logging.info(formatted_message)
        
        # Log to database if specified
        if log_to_db and db_conn:
            try:
                with db_conn.cursor() as cursor:
                    cursor.execute('''
                        INSERT INTO logs (timestamp, counter, uuid, process_type, step_runtime, total_runtime, message, user) 
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    ''', (time.strftime('%Y-%m-%d %H:%M:%S'), log_counter, session_uuid, process_type, step_runtime, total_runtime, message, current_user))
                db_conn.commit()
            except psycopg2.Error as e:
                print(f"An error occurred while inserting into the database: {e}")

    except Exception as e:
        print(f"Error logging message: {e}")

def close_log():
    global db_conn
    if db_conn:
        db_conn.close()