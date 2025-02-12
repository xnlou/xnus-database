import logging
import uuid
import time

session_uuid = str(uuid.uuid4())
log_counter = 0
start_time = None
last_log_time = None

def setup_logging(log_file):
    global log_counter, start_time, last_log_time
    log_counter = 0
    start_time = time.time()
    last_log_time = start_time
    
    # Clear any existing handlers
    logging.root.handlers = []
    
    logging.basicConfig(
        filename=log_file,
        level=logging.INFO,
        format='%(asctime)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    return session_uuid

def fLog(message):
    global log_counter, last_log_time
    
    try:
        log_counter += 1  # Increment the counter for each log entry
        
        current_time = time.time()
        total_runtime = current_time - start_time
        step_runtime = current_time - last_log_time
        
        # Format the log message with all the required information
        formatted_message = f"Counter: {log_counter} - UUID: {session_uuid} - Step Runtime: {step_runtime:.2f} - Total Runtime: {total_runtime:.2f} - {message}"
        
        last_log_time = current_time
        
        logging.info(formatted_message)
    except Exception as e:
        print(f"Error logging message: {e}")