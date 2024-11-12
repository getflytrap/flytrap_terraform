#!/bin/bash

JWT_SECRET_KEY=$(openssl rand -hex 32) # get from secret manager

# Write .env file with necessary environment variables
cat <<EOF > /home/ec2-user/api/.env
FLASK_APP="flytrap.py"
FLASK_ENV="production"
PGUSER="${db_user}"
PGHOST="${db_host}"
PGDATABASE="${db_name}"
PGPASSWORD="${db_password}"
PGPORT="5432"
JWT_SECRET_KEY="${JWT_SECRET_KEY}"
HTTPONLY="True"
SECURE="True"
SAMESITE="None"
USAGE_PLAN_ID="${api_gateway_usage_plan_id}"
AWS_REGION="${region}"
EOF

# Ensure correct permissions on the .env file
chmod 644 /home/ec2-user/api/.env