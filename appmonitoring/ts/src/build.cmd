del *.js.map
del *.js

del tests\*.js.map
del tests\*.js

call npm ci

call tsc --build || echo Build failed && exit /b
call npx eslint . || echo ESLint failed && exit /b 
call npm test || echo Jest failed && exit /b

call npx modclean
call npm prune --production

echo Done