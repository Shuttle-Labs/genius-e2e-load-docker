# Playwright Load Testing - Docker Setup

This Docker setup allows you to run your Playwright + Synpress tests in containerized environments for load testing.

## Files Included

- `Dockerfile` - Main Docker configuration
- `docker-compose.yml` - Docker Compose for easier orchestration
- `docker-run.sh` - Helper script for common operations
- `.env.example` - Environment variables template

## Prerequisites

- Docker installed and running
- Docker Compose (optional, but recommended)
- Your test repository (public or accessible)

## Quick Start

### 1. Setup Environment Variables

Copy `.env.example` to `.env` and fill in your values:

```bash
cp  .env.example .env
```

Edit `.env` with your actual values :

```env
BASE_URL=https://staging.your-app.com
SEED_PHRASE="your twelve or twenty four word seed phrase here"
METAMASK_PASSWORD="YourStrongPassword123"
```

### 2. Update Repository URL

Edit `docker-compose.yml` and `docker-run.sh` to point to your actual repository:

```yaml
# In docker-compose.yml
build:
  args:
    REPO_URL: https://github.com/Shuttle-Labs/genius-e2e-load-testing.git
    BRANCH: dev
```

### 3. Build the Image

```bash
# Using the helper script
./docker-run.sh build

# Or manually
docker build \
  --build-arg REPO_URL=https://github.com/your-username/your-repo.git \
  --build-arg BRANCH=dev \
  -t playwright-load-test:latest \
  .
```

### 4. Run Tests

#### Option A: Single Instance (Direct Docker)

```bash
./docker-run.sh run
```

#### Option B: Multiple Instances via Helper Script

```bash
# Run 10 parallel instances
./docker-run.sh run 10
```

#### Option C: Using Docker Compose

```bash
docker-compose up
```

## Detailed Usage

### Building the Image

The build process:

1. Uses official Playwright image with pre-installed browsers
2. Installs system dependencies (git, curl)
3. Clones your repository
4. Installs npm dependencies
5. Installs Playwright browsers
6. Builds Synpress MetaMask cache
7. Ready to run tests

Build time: ~5-10 minutes (depending on your repo size)

### Running Single Instance

```bash
docker run --rm \
  --shm-size=2g \
  --env-file .env \
  -v $(pwd)/playwright-results:/app/playwright/test-results \
  -v $(pwd)/playwright-report:/app/playwright/playwright-report \
  playwright-load-test:latest
```

Results will be saved to timestamped folders (for example `./playwright-results/20231126-150205/`) so each run stays separate:

- `./playwright-results/<timestamp>/` - Test results, videos, traces
- `./playwright-report/<timestamp>/` - HTML report

### Running Multiple Instances

For load testing, you can run multiple containers simultaneously:

Use the helper to scale up quickly:

```bash
# Run 50 parallel instances
./docker-run.sh run 50
```

Or launch them manually:

```bash
for i in {1..50}; do
  docker run --rm -d \
    --name playwright-test-$i \
    --shm-size=2g \
    --env-file .env \
    playwright-load-test:latest
done
```

### Viewing Results

After tests complete, view the HTML report:

```bash
cd playwright-report
python3 -m http.server 8080
# Open http://localhost:8080 in browser
```

## Customization

### Change Test Command

Edit the `CMD` in Dockerfile:

```dockerfile
# Run specific test file
CMD ["npx", "playwright", "test", "test/specific-test.spec.ts"]

# Run with specific workers
CMD ["npx", "playwright", "test", "--workers=2"]

# Run headed mode
CMD ["npx", "playwright", "test", "--headed"]
```

### Adjust Resources

```yaml
# In docker-compose.yml
services:
  playwright-load-test:
    shm_size: "4gb" # Increase if needed
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 4G
```

## Troubleshooting

### Issue: Synpress cache fails to build

**Solution:** The Dockerfile runs `npm run pw:syn:cache` during build. Make sure:

- Your `.env` has valid `SEED_PHRASE` and `METAMASK_PASSWORD`
- The seed phrase is a valid BIP39 mnemonic

If cache build fails during image build, you can comment it out and run it at runtime:

```dockerfile
# Comment this line in Dockerfile
# RUN npm run pw:syn:cache

# Then in CMD
CMD ["sh", "-c", "npm run pw:syn:cache && npm run pw:test"]
```

### Issue: Chrome crashes with "insufficient shared memory"

**Solution:** Increase shared memory size:

```bash
docker run --shm-size=4g ...
```

### Issue: Tests timeout

**Solution:** Increase timeout in `playwright.config.ts` or pass env variable:

```bash
docker run -e TEST_TIMEOUT=600000 ...
```

### Issue: Cannot access test results

**Solution:** Make sure volumes are mounted:

```bash
docker run \
  -v $(pwd)/playwright-results:/app/playwright/test-results \
  -v $(pwd)/playwright-report:/app/playwright/playwright-report \
  ...
```

## Performance Optimization

### For AWS Lambda/EC2 Deployment

1. **Pre-build and push image to ECR:**

   ```bash
   docker build -t playwright-load-test:latest .
   docker tag playwright-load-test:latest <ecr-repo>:latest
   docker push <ecr-repo>:latest
   ```

2. **Use smaller image (if needed):**

   - Consider multi-stage builds
   - Remove unnecessary dependencies
   - Use `.dockerignore` to exclude files

3. **Parallel execution:**
   - Each container runs independently
   - No shared state needed
   - Perfect for horizontal scaling

### Memory and CPU Recommendations

- **Minimum:** 2GB RAM, 1 CPU per container
- **Recommended:** 4GB RAM, 2 CPU per container
- **For 10k instances:** Use spot instances, auto-scaling groups

## Monitoring

Add monitoring to your tests:

```typescript
// In your test files
test.afterEach(async ({}, testInfo) => {
  console.log(`Test: ${testInfo.title}`);
  console.log(`Status: ${testInfo.status}`);
  console.log(`Duration: ${testInfo.duration}ms`);

  // Send metrics to CloudWatch, DataDog, etc.
});
```

## Cleanup

```bash
# Stop all running containers
./docker-run.sh clean

# Or manually
docker ps -a | grep playwright-test | awk '{print $1}' | xargs docker rm -f

# Remove images
docker rmi playwright-load-test:latest
```

## Next Steps for AWS Deployment

After testing locally:

1. Push image to Amazon ECR
2. Create ECS Task Definition or Lambda function
3. Use AWS Batch for large-scale parallel execution
4. Set up CloudWatch for monitoring
5. Use S3 for storing test results

---

## Support

For issues related to:

- Playwright: https://playwright.dev/docs/intro
- Synpress: https://github.com/Synthetixio/synpress
- Docker: https://docs.docker.com/

docker build --no-cache \
 --build-arg REPO_URL=https://github.com/Shuttle-Labs/genius-e2e-load-testing.git \
 --build-arg BRANCH=satyam2 \
 -f Dockerfile.fixed \
 -t playwright-load-test:latest \
 .

docker run --rm -it \
 --shm-size=2g \
 --env-file .env \
 --entrypoint /bin/bash \
 playwright-load-test:latest

Xvfb :99 -screen 0 1280x960x24 &
export DISPLAY=:99
sleep 2
cd /app/playwright
npx playwright test --headed --workers=1 --reporter=line

docker builder prune -a -f
