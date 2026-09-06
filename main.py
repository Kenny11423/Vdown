#!/usr/bin/env python3
"""
Main launcher for VDownloader CLI.
"""
import sys
from downloader.cli import main

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n[!] Quá trình đã bị người dùng dừng lại (Cancelled).")
        sys.exit(130)
