#!/bin/bash

# Script to build and run the Playwright load testing Docker container

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/Shuttle-Labs/genius-e2e-load-testing.git"
BRANCH="satyam2"
IMAGE_NAME="playwright-load-test"
DOCKERFILE="Dockerfile.fixed"
PLAYWRIGHT_CMD='set -x; cd /app/playwright && xvfb-run --auto-servernum --server-args="-screen 0 1280x960x24" npx playwright test --headed --workers 1'

TTY_ARGS=()
if [ -t 1 ]; then
    TTY_ARGS=(-it)
fi

echo -e "${GREEN}=== Playwright Load Testing Docker Setup ===${NC}\n"

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Warning: .env file not found!${NC}"
    echo "Please create .env file with the following variables:"
    echo "  - BASE_URL"
    echo "  - SEED_PHRASE"
    echo "  - METAMASK_PASSWORD"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Function to build the image
build_image() {
    echo -e "${GREEN}Building Docker image...${NC}"
    docker build \
        --no-cache \
        --build-arg REPO_URL=${REPO_URL} \
        --build-arg BRANCH=${BRANCH} \
        -f ${DOCKERFILE} \
        -t ${IMAGE_NAME}:latest \
        .
    echo -e "${GREEN}✓ Image built successfully${NC}\n"
}

# Function to run single instance
run_single() {
    echo -e "${GREEN}Running single test instance...${NC}"
    local timestamp
    timestamp=$(date +"%Y%m%d-%H%M%S")
    local host_results_dir="$(pwd)/playwright-results/${timestamp}"
    local host_report_dir="$(pwd)/playwright-report/${timestamp}"
    mkdir -p "${host_results_dir}" "${host_report_dir}"
    echo "Artifacts will be saved under:"
    echo "  Results:     ${host_results_dir}"
    echo "  HTML report: ${host_report_dir}"
    docker run --rm "${TTY_ARGS[@]}" \
        --shm-size=2g \
        --env-file .env \
        -v "${host_results_dir}:/app/playwright/test-results" \
        -v "${host_report_dir}:/app/playwright/playwright-report" \
        --entrypoint /bin/bash \
        ${IMAGE_NAME}:latest \
        -lc "${PLAYWRIGHT_CMD}"
}

# Function to run using docker-compose
run_compose() {
    echo -e "${GREEN}Running with docker-compose...${NC}"
    docker-compose up --build
}

# Function to run multiple instances
run_multiple() {
    local instances=$1
    echo -e "${GREEN}Running ${instances} parallel test instances...${NC}"
    
        for i in $(seq 1 $instances); do
            echo -e "${YELLOW}Starting instance $i...${NC}"
            docker run --rm -d \
                --name playwright-test-$i \
                --shm-size=2g \
                --env-file .env \
                ${IMAGE_NAME}:latest \
                "${PLAYWRIGHT_CMD[@]}" &
        done
    
    wait
    echo -e "${GREEN}✓ All instances completed${NC}"
}

# Function to clean up
cleanup() {
    echo -e "${GREEN}Cleaning up...${NC}"
    docker-compose down 2>/dev/null || true
    docker ps -a | grep playwright-test | awk '{print $1}' | xargs -r docker rm -f
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Main menu
case "${1:-}" in
    build)
        build_image
        ;;
    run)
        run_single
        ;;
    compose)
        run_compose
        ;;
    scale)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Please specify number of instances${NC}"
            echo "Usage: $0 scale <number>"
            exit 1
        fi
        build_image
        run_multiple $2
        ;;
    clean)
        cleanup
        ;;
    *)
        echo "Usage: $0 {build|run|compose|scale|clean}"
        echo ""
        echo "Commands:"
        echo "  build   - Build the Docker image"
        echo "  run     - Run a single test instance"
        echo "  compose - Run using docker-compose"
        echo "  scale N - Run N parallel instances"
        echo "  clean   - Clean up containers and images"
        echo ""
        echo "Examples:"
        echo "  $0 build          # Build the image"
        echo "  $0 run            # Run single instance"
        echo "  $0 scale 10       # Run 10 parallel instances"
        exit 1
        ;;
esac
