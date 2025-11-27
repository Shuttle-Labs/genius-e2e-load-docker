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

TTY_ARGS=()
if [ -t 1 ]; then
    TTY_ARGS=(-it)
fi

echo -e "${GREEN}=== Playwright Load Testing Docker Setup ===${NC}\n"

# Ensure image exists (build if missing)
ensure_image() {
    if ! docker image inspect ${IMAGE_NAME}:latest >/dev/null 2>&1; then
        echo -e "${YELLOW}Image ${IMAGE_NAME}:latest not found. Building now...${NC}"
        build_image
    fi
}

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

# Function to run instances (single or multiple)
run_instances() {
    local instances=${1:-1}
    ensure_image
    echo -e "${GREEN}Running ${instances} instance(s)...${NC}"
    local run_timestamp
    run_timestamp=$(date +"%Y%m%d-%H%M%S")
    local results_root="$(pwd)/playwright-results/${run_timestamp}"
    local report_root="$(pwd)/playwright-report/${run_timestamp}"
    mkdir -p "${results_root}" "${report_root}"

    if [ "$instances" -le 1 ]; then
        local host_results_dir="${results_root}"
        local host_report_dir="${report_root}"
        echo "Artifacts will be saved under:"
        echo "  Results:     ${host_results_dir}"
        echo "  HTML report: ${host_report_dir}"
        docker run --rm "${TTY_ARGS[@]}" \
            --shm-size=2g \
            --env-file .env \
            -v "${host_results_dir}:/app/playwright/test-results" \
            -v "${host_report_dir}:/app/playwright/playwright-report" \
            ${IMAGE_NAME}:latest
    else
        echo "Artifacts root:"
        echo "  Results:     ${results_root}"
        echo "  HTML report: ${report_root}"
        echo "Logs from parallel instances will stream below."
        local pids=()
        local exit_code=0
        for i in $(seq 1 $instances); do
            echo -e "${YELLOW}Starting instance $i...${NC}"
            local inst_results_dir="${results_root}/instance-$i"
            local inst_report_dir="${report_root}/instance-$i"
            mkdir -p "${inst_results_dir}" "${inst_report_dir}"
            docker run --rm \
                --name playwright-test-$i \
                --shm-size=2g \
                --env-file .env \
                -v "${inst_results_dir}:/app/playwright/test-results" \
                -v "${inst_report_dir}:/app/playwright/playwright-report" \
                ${IMAGE_NAME}:latest &
            pids+=($!)
            sleep 0.5
        done
        for pid in "${pids[@]}"; do
            if ! wait "$pid"; then
                exit_code=1
            fi
        done
        if [ "$exit_code" -ne 0 ]; then
            echo -e "${RED}One or more instances failed${NC}"
            exit "$exit_code"
        fi
        echo -e "${GREEN}✓ All instances completed${NC}"
    fi
}

# Function to run using docker-compose
run_compose() {
    echo -e "${GREEN}Running with docker-compose...${NC}"
    docker-compose up --build
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
        count=${2:-1}
        if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ]; then
            echo -e "${RED}Error: Run count must be a positive integer${NC}"
            exit 1
        fi
        run_instances "$count"
        ;;
    compose)
        run_compose
        ;;
    clean)
        cleanup
        ;;
    *)
        echo "Usage: $0 {build|run|compose|clean}"
        echo ""
        echo "Commands:"
        echo "  build    - Build the Docker image"
        echo "  run [N]  - Run once (default) or N parallel instances"
        echo "  compose  - Run using docker-compose"
        echo "  clean    - Clean up containers and images"
        echo ""
        echo "Examples:"
        echo "  $0 build      # Build the image"
        echo "  $0 run        # Run single instance"
        echo "  $0 run 5      # Run 5 parallel instances"
        exit 1
        ;;
esac
