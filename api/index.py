import sys
import os

# Set up paths so modules in app/ can be loaded
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(CURRENT_DIR)
APP_DIR = os.path.join(ROOT_DIR, "app")

for path in [ROOT_DIR, APP_DIR]:
    if path not in sys.path:
        sys.path.insert(0, path)

from server import WMSRequestHandler

# Vercel serverless function entrypoint
class handler(WMSRequestHandler):
    pass
