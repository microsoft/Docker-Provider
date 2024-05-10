#!/bin/bash

# Delete JS map files and JS files in the current directory
rm -f *.js.map
rm -f *.js

# Delete JS map files and JS files in the tests directory
rm -f tests/*.js.map
rm -f tests/*.js

# Run TypeScript compiler, handle errors
tsc --build || { echo "Build failed"; exit 1; }

# Run ESLint, handle errors
npx eslint . || { echo "ESLint failed"; exit 1; }

# Run Jest tests, handle errors
npm test || { echo "Jest failed"; exit 1; }

