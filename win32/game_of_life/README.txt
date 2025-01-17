/*********************************************************************
                            GAME  OF  LIFE
                            (using win32)

This example shows a simple setup for a game with Input processing,
updating game state and drawing game state to the screen.

You can
* Left-Click to bring a cell alive
* Right-Click to kill a cell
* Press <Space> to (un)pause the game
* Press <Esc> to close the game

The game starts paused.

Build with:

odin build . -resource:game_of_life.rc

**********************************************************************/

This project requires the windows SDK to be included an easy way to do that is either to run VCVars64.bat
OR run it from the "x64 Native Tools Command Prompt"

if you did not clone the repo directly and only have the folder you will get an error about the missing .ico 
its back 1 directory in the examples you can put it in the project folder and change the path on line 46 of the .rc
