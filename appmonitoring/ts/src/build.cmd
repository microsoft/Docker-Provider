rem call npm i @types/node
del *.js.map
del *.js
call tsc --build
rem call npm run lint 