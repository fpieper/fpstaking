@echo off
setlocal
cd %~dp0
elm-live src/Main.elm --pushstate --dir=static --host=0.0.0.0 -- --output=static/main.js
