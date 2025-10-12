#!/bin/bash
# Run both AI CLI and Flask API in background

# Start AI CLI
python3 -u ./scripts/ai_run.py &

# Start Flask app
python3 -u ./scripts/app.py &

# Wait for both to keep container running
wait