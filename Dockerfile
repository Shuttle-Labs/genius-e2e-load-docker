# Use official Playwright image with all browsers pre-installed
FROM mcr.microsoft.com/playwright:v1.48.2-jammy

# Set working directory
WORKDIR /app

# Install Node.js 20.x (if not already in base image)
RUN apt-get update && \
    apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Verify Node version
RUN node --version && npm --version

# Clone the repository
ARG REPO_URL
ARG BRANCH=main
RUN git clone ${REPO_URL} . && \
    git checkout ${BRANCH}

# Install dependencies
RUN npm ci

# Install Playwright browsers with dependencies
RUN npx playwright install --with-deps

# Set environment variables (these will be overridden at runtime)
ENV BASE_URL="https://staging.tradegenius.com"
ENV SEED_PHRASE="brick jeans notice danger fatigue judge turtle retire miss hold office sauce"
ENV METAMASK_PASSWORD="Tester@1234"

# Build Synpress MetaMask cache
RUN npm run pw:syn:cache

# Default command - run tests
CMD ["npm", "run", "pw:test"]
