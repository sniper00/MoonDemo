#!/bin/bash
if [ -x "./moon/moon" ]; then
    ./moon/moon main_game.lua 1
else
    cd moon && premake5 run --release ../main_game.lua 1
fi