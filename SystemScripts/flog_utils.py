import logging
import uuid
import time
import os

session_uuid = str(uuid.uuid4())
log_counter = 0
start_time = None
last_log_time = None
log_file = None
process_type = "default"  # Default process type, can be changed or set dynamically

def setup_logging(log_file_path):
    global session_uuid, log_counter, start_time, last_log_time
    
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
    
    return session_uuid

def fLog(message, process_type="default"):
    global log_counter, last_log_time
    
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
        
        # Explicitly write to the file
        # with open(log_file.name, 'a') as log:
        #     log.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - {formatted_message}\n")
        
        # Log using Python's logging for any other handlers or for consistency
        logging.info(formatted_message)
    except Exception as e:
        print(f"Error logging message: {e}")