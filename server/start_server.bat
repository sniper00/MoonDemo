IF EXIST moon\moon.exe (
    start cmd /k moon\moon.exe main_hub.lua 10000 node.json
) ELSE (
    cd moon && premake5 build --release
    cd ..
    start cmd /k "cd moon && premake5 run --release ..\main_hub.lua 10000 node.json"
)
timeout /t 1
IF EXIST moon\moon.exe (
    start cmd /k moon\moon.exe main_game.lua 1
) ELSE (
    start cmd /k "cd moon && premake5 run --release ..\main_game.lua 1"
)