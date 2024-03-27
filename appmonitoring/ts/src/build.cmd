del *.js.map
del *.js

del tests\*.js.map
del tests\*.js

call tsc --build || echo Build failed && exit /b
call npx eslint . || echo ESLint failed && exit /b 
call npm test || echo Jest failed && exit /b

echo Done