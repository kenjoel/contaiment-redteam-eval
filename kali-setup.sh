#!/bin/bash
# =============================================================================
# Containment Red-Team - Kali Linux Setup Script
# =============================================================================
# Run this script in your Kali VM terminal:
#   curl -sL <url> | bash
# Or copy-paste the commands below
# =============================================================================

set -e

echo "=========================================="
echo "  Containment Red-Team - Kali Setup"
echo "=========================================="
echo ""

# Step 1: Update system and install dependencies
echo "[Step 1/5] Installing dependencies..."
sudo apt update
sudo apt install -y bubblewrap libseccomp-dev python3 python3-pip python3-venv git

# Step 2: Clone the repository
echo ""
echo "[Step 2/5] Cloning repository..."
cd ~
git clone https://github.com/kenjoel/contaiment-redteam-eval.git containment-redteam
cd containment-redteam

# Step 3: Set up Python virtual environment
echo ""
echo "[Step 3/5] Setting up Python environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install gitpython pyyaml

# Step 4: Create test repository
echo ""
echo "[Step 4/5] Creating test repository..."
mkdir -p workspace/target-repo
cd workspace/target-repo
git init
git config user.email "demo@kali.local"
git config user.name "Demo Agent"
echo "# Target Repository" > README.md
git add README.md
git commit -m "Initial commit"
cd ../..

# Step 5: Run the PoC demo
echo ""
echo "[Step 5/5] Running the backdoor demonstration..."
echo ""
TARGET_REPO=$(pwd)/workspace/target-repo python3 poc/backdoor_demo.py

echo ""
echo "=========================================="
echo "  Now running the decoder..."
echo "=========================================="
TARGET_REPO=$(pwd)/workspace/target-repo python3 poc/decoder.py

echo ""
echo "=========================================="
echo "  SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "To run the FULL SANDBOX demo with seccomp/namespaces:"
echo "  ./run-with-sandbox.sh"
echo ""
