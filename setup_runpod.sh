#!/bin/bash
set -e

# Update apt-get and install less
apt-get update && apt-get install -y less

# Install gpustat using pip
pip install gpustat
