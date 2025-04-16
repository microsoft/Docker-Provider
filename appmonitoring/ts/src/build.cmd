@echo off
if exist "./out" (
    rmdir /S /Q "./out"
)

call npm i
call npm ci

call tsc --build || echo Build failed && exit /b
call npx eslint . || echo ESLint failed && exit /b 
call npm test || echo Jest failed && exit /b

if "%1" NEQ "noclean" (
    call npx modclean -r
    call npm prune --production
)

echo Done