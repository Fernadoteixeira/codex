#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Persistent Documentation Translator Runner.

Continuously runs batch translation until 100% of .md files are translated and verified.
"""

import json
import os
import subprocess
import sys
import time

os.environ['DEEPL_AUTH_KEY'] = '8319203e-8781-43d8-ba75-ea4be2fbd718:fx'

SCRIPT_PATH = r"C:\Users\fjuni\.gemini\config\skills\doc-translator-deeplx\scripts\translate_docs.py"
REPO_PATH = r"c:\Users\fjuni\codex"
SCAN_JSON = os.path.join(REPO_PATH, "scan_results.json")
BATCH_JSON = os.path.join(REPO_PATH, "batch_translation_results.json")


def scan():
    cmd = [
        "uv", "run", SCRIPT_PATH, "scan",
        "--path", REPO_PATH,
        "--extensions", ".md",
        "--output", SCAN_JSON
    ]
    subprocess.run(cmd, capture_output=True, text=True)
    if os.path.exists(SCAN_JSON):
        with open(SCAN_JSON, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

def run_batch():
    cmd = [
        "uv", "run", SCRIPT_PATH, "batch",
        "--path", REPO_PATH,
        "--extensions", ".md",
        "--skip-existing",
        "--resume",
        "--recycle-container",
        "--container-name", "docker-dlx-1",
        "--output", BATCH_JSON
    ]
    print("[PersistentRunner] Starting/Resuming batch translation...")
    proc = subprocess.run(cmd, text=True)
    return proc.returncode

def main():
    iteration = 1
    while True:
        data = scan()
        total = data.get("total_files", 0)
        translated = data.get("translated_files", 0)
        pending = data.get("pending_files", 0)
        percent = data.get("coverage_percent", 0.0)

        print(f"\n==================================================")
        print(f"[PersistentRunner] Iteration #{iteration}")
        print(f"Total files: {total} | Translated: {translated} | Pending: {pending} | Coverage: {percent:.1f}%")
        print(f"==================================================\n")

        if pending == 0 and total > 0:
            print("[PersistentRunner] 🎉 100% of documentation files translated!")
            break

        run_batch()

        # Brief pause before checking and resuming if needed
        print("[PersistentRunner] Batch paused or hit limit. Retrying in 15 seconds...")
        time.sleep(15)
        iteration += 1

if __name__ == "__main__":
    main()
