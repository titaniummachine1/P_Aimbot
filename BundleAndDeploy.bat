@echo off

node bundle.js
move /Y "PAimbot.lua" "%localappdata%"
exit