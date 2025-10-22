#!/usr/bin/env python3
"""
truncate_log.py

Safely truncate a large log file to keep only the most recent data while
creating a timestamped backup. Designed to work on Windows (WSL/PowerShell)
and Unix-like systems. The script preserves complete lines (doesn't cut a
line in half) and works efficiently on very large files.

Usage examples:
  python Tools/truncate_log.py "d:\\EA_Projetos\\Nexus_Confluence_MT5\\Nexus_Confluence_MT5\\log\\20251021.txt"
  python Tools/truncate_log.py /mnt/d/EA_Projetos/Nexus_Confluence_MT5/Nexus_Confluence_MT5/log/20251021.txt --max-mb 50 --keep-mb 45

Author: automated helper
"""
import argparse
import os
import shutil
import time
from pathlib import Path


def human_size(n):
    for unit in ['B','KB','MB','GB','TB']:
        if abs(n) < 1024.0:
            return f"{n:.2f} {unit}"
        n /= 1024.0
    return f"{n:.2f} PB"


def truncate_file_keep_tail(path: Path, max_mb: int = 50, keep_mb: int = 45):
    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")

    file_size = path.stat().st_size
    max_bytes = int(max_mb * 1024 * 1024)
    keep_bytes = int(keep_mb * 1024 * 1024)

    print(f"Current size: {human_size(file_size)} | limit: {max_mb} MB | keep: {keep_mb} MB")

    if file_size <= max_bytes:
        print("No truncation needed.")
        return False

    if keep_bytes >= file_size:
        print("Requested keep size is larger than file - nothing to do.")
        return False

    # Create backup
    ts = time.strftime('%Y%m%d_%H%M%S')
    backup_path = path.with_suffix(path.suffix + f'.bak.{ts}')
    print(f"Creating backup: {backup_path}")
    shutil.copy2(path, backup_path)

    # Read only the tail portion and preserve line boundaries
    with path.open('rb') as rf:
        # Seek to position where tail starts
        start_pos = max(0, file_size - keep_bytes)
        rf.seek(start_pos)

        # If we're in the middle of a line, discard the partial first line
        if start_pos != 0:
            _ = rf.readline()

        tail = rf.read()

    # Write tail back to original file atomically
    tmp_path = path.with_suffix(path.suffix + f'.truncating.{ts}')
    with tmp_path.open('wb') as wf:
        wf.write(tail)

    # Replace original file with truncated version
    tmp_path.replace(path)

    new_size = path.stat().st_size
    print(f"Truncation complete. New size: {human_size(new_size)}")
    return True


def main():
    parser = argparse.ArgumentParser(description='Truncate large log file keeping the most recent content and creating a backup.')
    parser.add_argument('file', help='Path to the log file to truncate')
    parser.add_argument('--max-mb', type=int, default=50, help='Maximum allowed file size in MB (default: 50)')
    parser.add_argument('--keep-mb', type=int, default=45, help='Amount in MB to keep from the end of file when truncating (default: 45)')
    args = parser.parse_args()

    path = Path(args.file)

    try:
        changed = truncate_file_keep_tail(path, max_mb=args.max_mb, keep_mb=args.keep_mb)
        if changed:
            print('File truncated and backup created.')
        else:
            print('No changes made.')
    except Exception as e:
        print('Error:', e)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
