#!/bin/bash

# Start FastAPI backend
echo "Starting FastAPI backend..."

# Activate venv if it exists
if [ -d ".venv" ]; then
    source .venv/bin/activate
fi

python3 src/api/main.py