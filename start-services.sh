#!/bin/bash

# Define the root directory for all services
ROOT_DIR="bqp-vijender-assignment"
mkdir -p $ROOT_DIR
cd $ROOT_DIR

# Function to check prerequisites
check_prerequisites() {
    # Check for Docker
    if ! command -v docker >/dev/null 2>&1 || ! command -v docker-compose >/dev/null 2>&1; then
        echo "Docker and Docker Compose are required but not found. Please install Docker to run the Docker services."
        exit 1
    fi

    # Check for Node.js and npm
    if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
        echo "Node.js and npm are required but not found. Please install Node.js and npm to run the React service."
        exit 1
    fi
}

# Check prerequisites before proceeding
check_prerequisites

# Function to clone or update repositories
clone_or_update_repo() {
    local repo_url=$1
    local dir_name=$2

    # Check if the directory exists
    if [ -d "$dir_name" ]; then
        echo "$dir_name exists. Checking for updates..."
        cd "$dir_name"
        # Check if the directory is a git repository
        if [ -d ".git" ]; then
            git pull
        else
            echo "Directory is not a git repository. Skipping..."
        fi
        cd ..
    else
        git clone "$repo_url" "$dir_name"
    fi
}

# Repositories and their directories
repos_urls=(
    "https://github.com/BQP-Test/auth_profile_service.git auth_profile_service"
    "https://github.com/BQP-Test/content_mgmt_service.git content_mgmt_service"
    "https://github.com/BQP-Test/comment_mgmt_service.git comment_mgmt_service"
    "https://github.com/BQP-Test/bqp_ui.git bqp_ui"
    "https://github.com/BQP-Test/notification_service.git notification_service"
)

# Clone or update each repository
for entry in "${repos_urls[@]}"; do
    set -- $entry
    repo_url=$1
    dir_name=$2
    clone_or_update_repo "$repo_url" "$dir_name"
done

# Define the relative path to each service
AUTH_PROFILE_SERVICE_PATH="./auth_profile_service"
CONTENT_SERVICE_PATH="./content_mgmt_service"
COMMENT_SERVICE_PATH="./comment_mgmt_service"
NOTIFICATION_SERVICE_PATH="./notification_service"
UI_SERVICE="./bqp_ui"

# Function to start a Docker Compose service using local.yml
start_service() {
    local service_path="$1"
    echo "Starting service in $service_path using local.yml"
    if [ -f "$service_path/local.yml" ]; then
        (cd "$service_path" && docker-compose -f local.yml up -d) || {
            echo "Failed to start service at $service_path with local.yml"
        }
    else
        echo "local.yml not found in $service_path"
    fi
    echo "-----------------------------------"
}

# Function to start the UI service
start_ui_service() {
    echo "Starting UI service in $UI_SERVICE"
    cd "$UI_SERVICE"
    echo "Installing dependencies..."
    if npm install; then
        echo "Dependencies installed."
        if npm run | grep -q 'start'; then
            echo "Starting the UI service..."
            npm start &
            REACT_PID=$!
            echo "UI service started successfully with PID $REACT_PID"
            wait $REACT_PID
        else
            echo "'start' script not found in package.json. Unable to start the UI service."
            cd ..
            return 1
        fi
    else
        echo "Failed to install dependencies."
        cd ..
        return 1
    fi
    cd ..
    echo "-----------------------------------"
}

# Function to cleanup services
cleanup() {
    echo "Stopping all services..."
    (cd "$AUTH_PROFILE_SERVICE_PATH" && [ -f "local.yml" ] && docker-compose -f local.yml down)
    (cd "$CONTENT_SERVICE_PATH" && [ -f "local.yml" ] && docker-compose -f local.yml down)
    (cd "$COMMENT_SERVICE_PATH" && [ -f "local.yml" ] && docker-compose -f local.yml down)
    (cd "$NOTIFICATION_SERVICE_PATH" && [ -f "local.yml" ] && docker-compose -f local.yml down)
    if [[ ! -z "$REACT_PID" ]]; then
        echo "Stopping React service with PID $REACT_PID..."
        kill $REACT_PID
    fi
    echo "All services have been stopped."
    exit 0
}

# Trap Ctrl+C and SIGTERM
trap 'cleanup' SIGINT SIGTERM

# Start all services
start_service $AUTH_PROFILE_SERVICE_PATH
start_service $CONTENT_SERVICE_PATH
start_service $COMMENT_SERVICE_PATH
start_service $NOTIFICATION_SERVICE_PATH
start_ui_service $UI_SERVICE  # Starting the React UI service

# Keep script running until signaled to stop
echo "Services are running. Press Ctrl+C to stop all services."
while true; do sleep 1; done
