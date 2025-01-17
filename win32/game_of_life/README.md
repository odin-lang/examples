# Game of life 
This example shows a simple setup for a game with Input processing,
updating game state and drawing game state to the screen.

You can
* `Left-Click` to bring a cell alive
* `Right-Click` to kill a cell
* Press `Space` to (un)pause the game
* Press `Esc` to close the game

## Build
`odin build . -resource:game_of_life.rc`

You need to have the proper windows includes or else the .rc compilation will fail and you wont get the custom icon to get these either

run vcvars64.bat before you build to set up your environment
its located at `Microsoft Visual Studio\YOUR_VERSION\BuildTools\VC\Auxiliary\Build`
NOTE: if you are using powershell this seems to fail as it doesnt export the variables properly use CMD instead

or

build it from the `x64 Native Tools Command Prompt` also included with visual studio