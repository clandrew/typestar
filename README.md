# Type Star
This is a simple typing game for Foenix F256K, made in a few hours for a Foenix F256* game jam organized by the Foenix community the weekend of April 6th, 2024.

Controls:
* Press the space bar at the title screen to start the game.
* Press the space bar at the game over screen to play again.
* Use the alphanumeric keys during gameplay.

Objective:
* Type the keys that match falling letters.
* When you hit a key, the corresponding letter disappears. Hit the key before the letter hits the bottom!
* If a letter hits the bottom, you lose a life.
  * Lives are shown on the HUD at the top right.
* If you lose all lives, the game is over. There is a prompt to try again.

![alt text](https://raw.githubusercontent.com/clandrew/typestar/main/Images/TitleEmu.png?raw=true)

## System Requirements

The game can be run on FoenixIDE emulator, or on F256K hardware. It requires 65816-based F256K.

The reason for depending on F256K is because keys are read from the built-in matrix keyboard.

The reason for depending on 65816-based CPU is because I was short on time and used 16bit addressing to get it done faster.

## Build

This demo is set up using Visual Studio 2019 which calls [64tass](https://tass64.sourceforge.net) assembler.

There are Visual Studio custom build steps which call into [64tass](https://tass64.sourceforge.net). You may need to update these build steps to point to wherever the 64tass executable lives on your machine. I noticed good enough integration with the IDE, for example if there is an error when assembling, the message pointing to the line number gets conveniently reported through to the Errors window that way.

For a best experience, consider using [this Visual Studio extension](https://github.com/clandrew/vscolorize65c816) for 65c816-based syntax highlighting.

The build generates a .PGZ executable.

## Release

If you don't want to build, you can simply download a release here.

## Launching the game

To run the game on hardware, put the PGZ file, for example, on an SD card and insert the SD card into the F256K. Then, from SuperBASIC, use 
```
/- typing.pgz
```

Or, to start the game from the microkernel DOS, use
```
- typing.pgz
```

with a space after the hyphen.
