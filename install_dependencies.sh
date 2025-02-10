#!/bin/bash

# Update package lists
sudo apt update

# Install cron if not already installed
sudo apt install -y cron

# Install Git if not already installed
sudo apt install -y git

# Start and enable cron service (if needed)
sudo systemctl start cron
sudo systemctl enable cron