# SDL Version of crisp-game-lib-portable
![DownloadCountTotal](https://img.shields.io/github/downloads/joyrider3774/crisp-game-lib-portable-sdl/total?label=total%20downloads&style=plastic) ![DownloadCountLatest](https://img.shields.io/github/downloads/joyrider3774/crisp-game-lib-portable-sdl/latest/total?style=plastic) ![LatestVersion](https://img.shields.io/github/v/tag/joyrider3774/crisp-game-lib-portable-sdl?label=Latest%20version&style=plastic) ![License](https://img.shields.io/github/license/joyrider3774/crisp-game-lib-portable-sdl?style=plastic)

<img src="./docs/screenshotFunkeyRgnano.gif" width="33%"><img src="./docs/screenshotRGB30.gif" width="33%"><img src="./docs/screenshotTrimuiSmartPro.gif" width="33%">

This is a repo containing sdl ports of the crisp games library which is a Minimal C-lang library for creating classic arcade-like mini-games running on devices and browsers. 
Re-implemented version of [crisp-game-lib](https://github.com/abagames/crisp-game-lib) for smaller devices. You can play [sample games in your browser](https://abagames.github.io/crisp-game-lib-portable/build/).



see [src/cglpSDL1](https://github.com/joyrider3774/crisp-game-lib-portable-sdl/tree/main/src/cglpSDL1) for SDL 1 Port
- keyboard or mouse only
- Sound support
- Extra added games
- Sections inside the menu's
- Ability to have more than 16 games in the menu
- Ability to switch between dark color mode enabled or not
- Overlays like small glow effects, pixel grid or crt effect saved per game
- HiScore saving
- Funkey version is based on this version
  
see [src/cglpSDL2](https://github.com/joyrider3774/crisp-game-lib-portable-sdl/tree/main/src/cglpSDL2) for SDL 2 Port
- keyboard, mouse or gamepads support using Gamecontroller Api
- Sound support
- Extra added games
- Sections inside the menu's
- Ability to have more than 16 games in the menu
- Ability to switch between dark color mode enabled or not
- Ability to switch between dark color mode enabled or not
- Overlays like small glow effects, pixel grid or crt effect saved per game
- HiScore saving
- Works on many chinese emulation handhelds if you crosscompile (rg35xx sp, rg35xx plus, trimui smart pro, rgb30, ..)

see [src/cglpSDL3](https://github.com/joyrider3774/crisp-game-lib-portable-sdl/tree/main/src/cglpSDL3) for SDL 3 Port
- keyboard, mouse or gamepads support using Gamepad Api
- Sound support
- Extra added games
- Sections inside the menu's
- Ability to have more than 16 games in the menu
- Ability to switch between dark color mode enabled or not
- Ability to switch between dark color mode enabled or not
- Overlays like small glow effects, pixel grid or crt effect saved per game
- HiScore saving

**Prebuild versions of the SDL2 and SDL3 port are available in the [release Section](https://github.com/joyrider3774/crisp-game-lib-portable-sdl/releases/latest/).**

Controls:
- Keyboard Controls: X, C, S, D, G, ESC, PageUp, PageDown and arrow keys
- Game Pad (XBox) Controls: A, B, X, Y, Start, Back, LB, RB and Joystick or dpad

Commandline parameters:

Usage: `CglpSDL3.exe [-w <WIDTH>] [-h <HEIGHT>] [-f] [-ns] [-a] [-fps] [-nd] [-g <GAMENAME>] [-ms] [-cgl] [-nsd] [CGL file]`

Commands:
- `-f`: Run fullscreen windowed (desktop resolution)
- `-w XXX`: use window width XXX
- `-h YYY`: use window height YYY
- `-ns`: no sound
- `-a`: use accelerated renderer (by default software renderer is used)
- `-fps`: show fps
- `-nd`: no fps delay (run as fast as possible)
- `-list`: List game names to be used with -g option
- `-g <GAMENAME>`: run game <GAMENAME> only
- `-ms`: Make screenshot of every game
- `-cgl`: create fake <GAMENAME>.cgl rom files which can be used as a parameter to launch the games
- `-nsd`: No scaled drawing (scales the view, instead of drawing scaled, is faster but disables overlays, glow etc)
- `CGL file`: Pass a .cgl file to launch a game directly

**Windows Prebuild Versions**

Windows versions will run fine on any recent os and SDL2 library is baked in, what will not work is running the x64 versions on a 32bit os but 32bit versions are available for download as well

**Mac Prebuild Versions and gatekeeper**

Macos prebuild binaries are now available as well for different os and architecture versions and contain the sdl2 lib in the binary. Generally speaking binaries build on older versions of macos will run
fine on a newer macos if you keep using same architecture but not the other way around. I personally tested the mac os intel builds (not arm ones) on mac os sequoia 15.2 i did not test the arm versions.
However due to apple requiring signed and notarized binaries, macos will probably prevent you from running the app bundle directly and display a message like in the screenshot below

<img src="metadata/mac_gatekeeper1.png">

If this happens you need to go to `system settings` in the `privacy and security` section and scroll all the way down, there will be an entry there where you can unblock it as you can see in 
screenshot below

<img src="metadata/mac_gatekeeper2.png">

once you click allow it will show a new dialog where you choose to open the binary, but you may have to provide the administrator password. 

<img src="metadata/mac_gatekeeper3.png">

once you have done this a single time it won't ask about this again.

**(Ubuntu) Linux Prebuild Versions**

Linux prebuild versions are only available for ubuntu flavor os'es and contain sdl2 in the binary already so you don't need to deal with apt normally. However since there are only ubuntu runners on github i can not provide binaries for other
os'es and the prebuild ones for ubuntu might not work on other os'es. You will just have to build them manually then from source which is not that hard. (More info below). Generally speaking binaries build on older versions of an os will run
fine on a newer os but not the other way around. I did not test the Arm versions of the binaries

## Target devices

<img src="./docs/screenshotM5StickCPlus.gif" width="33%"><img src="./docs/screenshotPlaydate.gif" width="33%"><img src="./docs/screenshotPyBadge.gif" width="33%">


- [M5StickC PLUS](https://docs.m5stack.com/en/core/m5stickc_plus)
- [M5Stack BASIC](http://docs.m5stack.com/en/core/basic)
- [Playdate](https://play.date/) (Download [crisp-games.pdx.zip](https://abagames.github.io/crisp-game-lib-portable/crisp-games.pdx.zip) and sideload a game.)
- [Adafruit PyBadge](https://learn.adafruit.com/adafruit-pybadge)
- [Arduboy](https://www.arduboy.com/)
- [ESP32-2432S028R](https://ja.aliexpress.com/item/1005004502250619.html)
- [ESPboy](https://www.espboy.com/)
- [Funkey](https://www.funkey-project.com/)
- [RG Nano](https://anbernic.com/products/rg-nano)
- [SDL 1, 2 or 3 supported device](https://www.libsdl.org/)

## Sample game codes and reference

- [Sample game codes](https://github.com/abagames/crisp-game-lib-portable/tree/main/src/games)
- Reference
  - [Functions and variables](https://abagames.github.io/crisp-game-lib-portable/ref_document/html/cglp_8c.html)
  - [Structs and macros](https://abagames.github.io/crisp-game-lib-portable/ref_document/html/cglp_8h.html)
  - [2d vector functions](https://abagames.github.io/crisp-game-lib-portable/ref_document/html/vector_8c.html) ([macros](https://abagames.github.io/crisp-game-lib-portable/ref_document/html/vector_8h.html))

## How to write your own game

1. Copy [game_Template.c](https://raw.githubusercontent.com/abagames/crisp-game-lib-portable/main/src/games/game_Template.c) to `game[your game name].c`

1. Comment out other games in [menuGameList.c](https://github.com/abagames/crisp-game-lib-portable/blob/main/src/lib/menuGameList.c) and add `void addGame[your game name]();` and `addGame[your game name]()`

   ```
   ...(snip)...
   void addGameReflector();
   void addGame[your game name]();

   void addGames() {
     /*addGameThunder();
     ...(snip)...
     addGameReflector();*/
     addGame[your game name]();
   }
   ```

1. Write your own game in `game[your game name].c` and rename `void addGame_Template() {` to `void addGame[your game name]() {`

1. [Build for browser](#browser) and debug

1. Once the game is complete, revert other games that were commented out in [menuGameList.c](https://github.com/abagames/crisp-game-lib-portable/blob/main/src/lib/menuGameList.c) and build it for other devices

## Build for [target device]

### M5StickCPlus, M5Stack, PyBadge

1. Install [LovyanGFX library](https://github.com/lovyan03/LovyanGFX)

1. Create `cglp[target device]/` directory (e.g. `cglpM5StickCPlus/`)

1. Copy `cglp[target device].ino`, [./src/lib/\*](https://github.com/abagames/crisp-game-lib-portable/tree/main/src/lib) and [./src/games/\*](https://github.com/abagames/crisp-game-lib-portable/tree/main/src/games) files to the directory

   - [cglpM5StickCPlus.ino](https://github.com/abagames/crisp-game-lib-portable/blob/main/src/cglpM5StickCPlus/cglpM5StickCPlus.ino)
   - [cglpM5Stack.ino](https://gist.github.com/obono/1606cf8a8a4e9c9f97de4ebebad3460a) (ported by [OBONO](https://github.com/obono))
   - [cglpPyBadge.ino](https://github.com/abagames/crisp-game-lib-portable/blob/main/src/cglpPyBadge/cglpPyBadge.ino)

1. Verify and upload `cglp[target device].ino` with [Arduino IDE](https://www.arduino.cc/en/software)

### Playdate

1. Copy [./src/cglpPlaydate](https://github.com/abagames/crisp-game-lib-portable/tree/main/src/cglpPlaydate) directory

1. Create `cglpPlaydate/build` directory

1. Move to `cglpPlaydate/build` directory and `cmake ..`

1. Open `crisp-game-lib-portable.sln` with Visual Studio

1. Build the solution (see [Building for the Simulator using Visual Studio](https://sdk.play.date/2.3.1/Inside%20Playdate%20with%20C.html#_building_for_the_simulator_using_visual_studio))

1. See also [Building for the Playdate using NMake](https://sdk.play.date/2.3.1/Inside%20Playdate%20with%20C.html#_building_for_the_playdate_using_nmake)

### Arduboy

Note: Some features are limited due to device resource limitations.

- [crisp-game-lib-arduboy](https://github.com/obono/crisp-game-lib-arduboy) (ported by [OBONO](https://github.com/obono))

### ESP32-2432S028R

- [cglp-dentaroUI](https://github.com/dentaro/cglp-dentaroUI) (ported by [dentaro](https://github.com/dentaro))

### ESPboy

- [cglpESPboy](https://github.com/ESPboy-edu/ESPboy_crisp-game-lib-portable/tree/main/cglpESPboy) (ported by [ESPboy](https://github.com/ESPboy-edu))

### Funkey or RG-Nano

- [cglpFunkey](https://github.com/joyrider3774/crisp-game-lib-portable-funkey) (ported by [Joyrider3774](https://github.com/joyrider3774))

### Any Device supporting SDL1, SDL2 or SDL3

1. (Cross)compile using provided `Makefile` by running `make -f ./src/cglpSDL2/Makefile` or `make -f ./src/cglpSDL1/Makefile` in rootfolder of this repo or use the `CMake` with the provided `src/cglpSDL2/CMakelists` or `src/cglpSDL3/CMakelists` file

1. Checkout `binary --help` for information on commandline parameters

- SDL2 & 3 port supports game controllers SDL1 port only keyboard

- ported by [Joyrider3774](https://github.com/joyrider3774)

### Browser

1. Install [Emscripten](https://emscripten.org/)

1. Run `dev` npm script to start the dev server and watch [js files](https://github.com/abagames/crisp-game-lib-portable/tree/main/src/browser)

1. Run `dev_c` npm script to watch [c files](https://github.com/abagames/crisp-game-lib-portable/tree/main/src/lib) and build [wasm files](https://github.com/abagames/crisp-game-lib-portable/tree/main/public/wasm)

## How to operate

### Back to the game selection menu

- Hold down the A button and press the B button (M5StickCPlus, M5Stack)
- Press the SELECT button (PyBadge)
- Press A, B, Up and Right buttons simultaneously (Playdate)
- Press the X key while holding down the up and down arrow keys (Browser)
- Press ESC on SDL Ports

### Toggle sound on/off

- Press the B button (M5StickCPlus)
- Press the C Button (M5Stack)
- Press the START button (PyBadge)
- Press the Z key while holding down the up and down arrow keys (Browser)

### Key assignment on SDL Ports

- (A) X key, (B) C key, (left/right/up/down) arrow keys

### Key assignment on browser

- (A) X key, (B) Z key, (left/right/up/down) arrow keys

## How to port the library to other devices

The source codes for [library](https://github.com/abagames/crisp-game-lib-portable/tree/main/src/lib) and [games](https://github.com/abagames/crisp-game-lib-portable/tree/main/src/games) are written device-independent. Besides, you need to implement device-dependent code for the following functions:

- Device initialization function (e.g. `setup()` in Arduino) that calls `initGame()`

- Frame update function (e.g. `loop()` in Arduino) that calls `setButtonState()` and `updateFrame()`

  - The state of the button press must be notified to the library with the `setButtonState()`

- Drawing and audio processing functions that are defined in [machineDependent.h](https://github.com/abagames/crisp-game-lib-portable/blob/main/src/lib/machineDependent.h)
  - `md_getAudioTime()` function should return the audio timer value in seconds
  - `md_playTone(float freq, float duration, float when)` function should play a tone with `freq` frequency, `duration` length (in seconds) and staring from `when` seconds on the audio timer
  - `md_drawCharacter(unsigned char grid[CHARACTER_HEIGHT][CHARACTER_WIDTH][3], float x, float y, int hash)` function should draw the pixel art defined by `grid[y][x][r, g, b]` at position (x, y). Since `hash` will be the same for the same pixel art, you can cache pixel art images using `hash` as an index and avoid redrawing the same image

Sample device-dependent codes are [cglpM5StickCPlus.ino](https://github.com/abagames/crisp-game-lib-portable/blob/main/src/cglpM5StickCPlus/cglpM5StickCPlus.ino) and [cglpPyBadge.ino](https://github.com/abagames/crisp-game-lib-portable/blob/main/src/cglpPyBadge/cglpPyBadge.ino).

## Porting games from crisp-game-lib using an AI chatbot

You can use an AI chatbot to port game source code for crisp-game-lib to crisp-game-lib-portable. By providing the [prompt](./convert_prompt/prompt.txt) and [set of files](./convert_prompt/knowledge/) to the chatbot, you can obtain the code ported to the C language. I have tried this using [Claude 3 Opus](https://www.anthropic.com/news/claude-3-family), but it is expected to work to some extent with other LLMs as well. The ported code is not perfect, so it needs to be manually checked and corrected.
