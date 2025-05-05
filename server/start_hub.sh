#!/bin/bash

if [ -x "./moon/moon" ]; then
    ./moon/moon main_hub.lua 10000 node.json
else
    cd moon && premake5 run --release ../main_hub.lua 10000  node.json
fi
