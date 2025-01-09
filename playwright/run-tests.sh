#!/bin/bash
set -e

if [ ! "$(ls -A node_modules 2>/dev/null)" ]; then
  echo "node_modules is empty. Installing dependencies..."
  npm ci
else
  echo "Dependencies already installed."
fi

if [ -n "$(ls ${PLAYWRIGHT_BROWSERS_PATH}/chromium*)" ]; then
  echo "Playwright browsers already installed."
else
  echo "Playwright browsers are missing. Installing..."
  npx playwright install --with-deps chromium --only-shell
fi

npx playwright test