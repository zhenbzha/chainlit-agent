#!/bin/bash

# Output environment variables to .env file using azd env get-values
azd env get-values > .env

echo "--- ✅ | 1. Post-provisioning - env configured ---"

# Setup virtual environment
echo 'Setting up virtual environment...'
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
echo 'Installing dependencies from "requirements.txt"'
pip install -r ./src/api/requirements.txt > /dev/null
pip install ipython ipykernel jupyter nbconvert > /dev/null
ipython kernel install --name=python3 --user > /dev/null
jupyter kernelspec list > /dev/null
echo "--- ✅ | 2. Post-provisioning - ready execute notebooks ---"

echo "Populating data ...."
jupyter nbconvert --execute --to python --ExecutePreprocessor.timeout=-1 data/product_info/create-azure-search.ipynb > /dev/null
echo "--- ✅ | 3. Post-provisioning - populated data ---"
