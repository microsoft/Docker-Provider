rem call npm i @types/node
del *.js.map
del *.js

rem call npm install

call tsc --build
call npx eslint *.ts

rem call rm -r node_modules