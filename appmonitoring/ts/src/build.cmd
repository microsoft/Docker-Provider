call del *.js.map
call del *.js

call tsc --build && npx eslint *.ts