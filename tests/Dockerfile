FROM mcr.microsoft.com/playwright:v1.60.0-noble

WORKDIR /tests

# Copy package files first for layer caching
COPY package.json ./
RUN npm install

# Copy test files
COPY playwright.config.ts ./
COPY specs/ ./specs/

# Default: run all tests
CMD ["npx", "playwright", "test"]
