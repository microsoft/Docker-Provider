del *.js.map
del *.js
call tsc --build
call npm run lint 