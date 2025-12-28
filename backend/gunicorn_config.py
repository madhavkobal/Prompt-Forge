"""
Gunicorn configuration for production deployment
"""
import multiprocessing
import os

# Server socket
bind = f"0.0.0.0:{os.getenv('PORT', '8000')}"
backlog = 2048

# Worker processes
workers = int(os.getenv('WORKERS', multiprocessing.cpu_count() * 2 + 1))
worker_class = os.getenv('WORKER_CLASS', 'uvicorn.workers.UvicornWorker')
worker_connections = int(os.getenv('WORKER_CONNECTIONS', 1000))
max_requests = 1000  # Restart workers after this many requests (helps with memory leaks)
max_requests_jitter = 50  # Add randomness to max_requests
timeout = int(os.getenv('TIMEOUT', 120))
keepalive = int(os.getenv('KEEPALIVE', 5))

# Logging
accesslog = '-'  # Log to stdout
errorlog = '-'   # Log to stderr
loglevel = os.getenv('LOG_LEVEL', 'info').lower()
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# Process naming
proc_name = os.getenv('APP_NAME', 'promptforge')

# Server mechanics
daemon = False
pidfile = None
umask = 0
user = None
group = None
tmp_upload_dir = None

# SSL (if terminating SSL at application level)
# keyfile = '/path/to/keyfile'
# certfile = '/path/to/certfile'

# Security
limit_request_line = 4094
limit_request_fields = 100
limit_request_field_size = 8190

# Debugging (development only)
reload = False
reload_engine = 'auto'
spew = False

# Server hooks
def on_starting(server):
    """Called just before the master process is initialized."""
    print(f"Starting {proc_name} with {workers} workers")

def on_reload(server):
    """Called to recycle workers during a reload via SIGHUP."""
    print(f"Reloading {proc_name}")

def when_ready(server):
    """Called just after the server is started."""
    print(f"{proc_name} is ready. Listening on {bind}")

def on_exit(server):
    """Called just before exiting gunicorn."""
    print(f"Shutting down {proc_name}")

def worker_int(worker):
    """Called when a worker receives the SIGINT or SIGQUIT signal."""
    print(f"Worker {worker.pid} received SIGINT/SIGQUIT")

def worker_abort(worker):
    """Called when a worker receives the SIGABRT signal."""
    print(f"Worker {worker.pid} received SIGABRT")

def pre_fork(server, worker):
    """Called just before a worker is forked."""
    pass

def post_fork(server, worker):
    """Called just after a worker has been forked."""
    print(f"Worker spawned (pid: {worker.pid})")

def post_worker_init(worker):
    """Called just after a worker has initialized the application."""
    print(f"Worker initialized (pid: {worker.pid})")

def worker_exit(server, worker):
    """Called just after a worker has been exited."""
    print(f"Worker exited (pid: {worker.pid})")

def nworkers_changed(server, new_value, old_value):
    """Called when the number of workers changes."""
    print(f"Workers changed from {old_value} to {new_value}")

def pre_exec(server):
    """Called just before a new master process is forked."""
    print("Forking a new master process")
