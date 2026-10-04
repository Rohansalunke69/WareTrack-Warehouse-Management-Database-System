#!/usr/bin/env python3
"""
WareTrack WMS - All-in-One Launcher
Initializes the database engine and launches the local web management system.
"""

import sys
import os
import webbrowser

# Add app directory to sys.path
APP_DIR = os.path.join(os.path.dirname(__file__), "app")
sys.path.insert(0, APP_DIR)

from server import run_server

if __name__ == '__main__':
    port = 5050
    print("=" * 60)
    print(" 📦 WareTrack — Warehouse Management Database System & PL/SQL Engine")
    print("=" * 60)
    print(f" Web Server starting on: http://localhost:{port}")
    print(" Database: Initialized with Oracle schema parity & sample data.")
    print("=" * 60)
    
    # Try opening the browser
    try:
        webbrowser.open(f"http://localhost:{port}")
    except Exception:
        pass

    run_server(port=port)
