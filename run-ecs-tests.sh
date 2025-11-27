#!/usr/bin/env bash

# Run multiple ECS Fargate tasks in parallel to execute the load tests.
# Requires AWS CLI v2 and jq to be installed locally and authenticated.

set -euo pipefail


COUNT=1
REPOSITORY_URI="445914872260.dkr.ecr.us-east-2.amazonaws.com/e2e_load_test"
IMAGE_TAG="latest"
IMAGE_URI=""
CLUSTER="genius-prod"
SUBNETS="subnet-0605079c59fba5813,subnet-0a461074aeea16af2,subnet-0597f736277923acb"
SECURITY_GROUPS="sg-09183189a89890aeb"
TASK_DEF_PATH=" task-definition-e2e-load.json"
ASSIGN_PUBLIC_IP="ENABLED"

usage() {
  cat <<'EOF'
Usage: ./run-ecs-tests.sh [options]

Options:
  -c, --count N             Number of parallel tasks to start (default: 1)
  -h, --help                Show this help message

Examples:
  ./run-ecs-tests.sh
  ./run-ecs-tests.sh --count 25
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--count)
      COUNT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -le 0 ]; then
  echo "Count must be a positive integer." >&2
  exit 1
fi

if [ -z "$IMAGE_URI" ]; then
  IMAGE_URI="${DEFAULT_REPOSITORY_URI}:${IMAGE_TAG}"
fi

for var_name in CLUSTER SUBNETS SECURITY_GROUPS; do
  if [ -z "${!var_name}" ]; then
    echo "Missing required value: $var_name. Set it via env var or CLI option." >&2
    exit 1
  fi
done

if [ ! -f "$TASK_DEF_PATH" ]; then
  echo "Task definition file not found: $TASK_DEF_PATH" >&2
  exit 1
fi

command -v aws >/dev/null 2>&1 || { echo "aws CLI not found in PATH."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found in PATH."; exit 1; }

echo "Preparing task definition from $TASK_DEF_PATH using image $IMAGE_URI"
TMP_TASK_DEF=$(mktemp)
jq --arg image "$IMAGE_URI" '
  .containerDefinitions = (.containerDefinitions | map(.image = $image))
' "$TASK_DEF_PATH" > "$TMP_TASK_DEF"

echo "Registering task definition..."
REGISTER_OUTPUT=$(aws ecs register-task-definition --cli-input-json "file://$TMP_TASK_DEF")
rm -f "$TMP_TASK_DEF"
TASK_DEF_ARN=$(echo "$REGISTER_OUTPUT" | jq -r '.taskDefinition.taskDefinitionArn')

if [ -z "$TASK_DEF_ARN" ] || [ "$TASK_DEF_ARN" = "null" ]; then
  echo "Failed to register task definition."
  exit 1
fi
echo "Registered task definition: $TASK_DEF_ARN"

echo "Starting $COUNT task(s) in cluster $CLUSTER..."
PAYLOAD=$(jq -n \
  --arg cluster "$CLUSTER" \
  --arg task "$TASK_DEF_ARN" \
  --arg subnets "$SUBNETS" \
  --arg sgs "$SECURITY_GROUPS" \
  --arg assign "$ASSIGN_PUBLIC_IP" \
  --argjson count "$COUNT" \
  '{
    cluster: $cluster,
    taskDefinition: $task,
    launchType: "FARGATE",
    count: $count,
    networkConfiguration: {
      awsvpcConfiguration: {
        subnets: ($subnets | split(",")),
        securityGroups: ($sgs | split(",")),
        assignPublicIp: $assign
      }
    }
  }')

RUN_OUTPUT=$(aws ecs run-task --cli-input-json "$PAYLOAD")

FAILURES=$(echo "$RUN_OUTPUT" | jq '.failures | length')
if [ "$FAILURES" -gt 0 ]; then
  echo "Some tasks failed to start:"
  echo "$RUN_OUTPUT" | jq '.failures'
fi

TASK_ARNS=$(echo "$RUN_OUTPUT" | jq -r '.tasks[].taskArn')
if [ -z "$TASK_ARNS" ]; then
  echo "No tasks started successfully." >&2
  exit 1
fi

echo "Waiting for tasks to stop..."
mapfile -t TASK_ARN_ARRAY <<< "$TASK_ARNS"
aws ecs wait tasks-stopped --cluster "$CLUSTER" --tasks "${TASK_ARN_ARRAY[@]}"

echo "Task results:"
aws ecs describe-tasks --cluster "$CLUSTER" --tasks "${TASK_ARN_ARRAY[@]}" \
  | jq -r '.tasks[] | "\(.taskArn) - \(.lastStatus) - containers: " + (.containers[] | "\(.name)=exit(\(.exitCode // "unknown"))" )'

echo "Done. Check CloudWatch Logs group /ecs/e2e-load-test for detailed output."
