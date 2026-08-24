# PortableRadio

Adds a portable radio to Project Silverfish.

## Installation

1. Download the experimental build of [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases) (use `experimental-latest`). UE4SS installation guide: <https://github.com/UE4SS-RE/RE-UE4SS#basic-installation>.
2. Copy the `PortableRadio` folder into `Project Silverfish/SilverFish/Binaries/Win64/ue4ss/Mods/`.
3. Make sure the `enabled.txt` file exists in the `PortableRadio` folder.
4. Start the game. UE4SS loads the mod automatically.

## Keybinds

Change keybinds in `config.ini`:

- **Toggle Radio**: `F5`
- **Volume Up**: `+` (`ADD`)
- **Volume Down**: `-` (`SUBTRACT`)
- **Next Track**: `F4`

## How to Use

1. Start the game and load into a level.
2. Press `F5` to turn the radio on or off.
3. Press `F4` to skip to the next track.
4. Press or hold `+` and `-` on the numpad to adjust volume.

## Configuration

Edit `config.ini` to change settings:

### General

- `Debug`: Set to `true` to print debug messages to the console.

### Keybinds

- `ToggleKey`: Key to turn the radio on or off (e.g. `F5`).
- `VolumeUpKey`: Key to increase volume (e.g. `ADD`).
- `VolumeDownKey`: Key to decrease volume (e.g. `SUBTRACT`).
- `NextTrackKey`: Key to skip to the next track (e.g. `F4`). Set to `None` to disable.

### Audio

- `EnableToggleSound`: Play mechanical cassette sound on toggle.
- `ToggleSoundVolume`: Volume multiplier for toggle sound.
- `DefaultVolume`: Radio volume multiplier (`0.0` to `2.0`). Saves automatically when adjusted in-game.
- `VolumeStep`: Volume change amount per key press or hold tick.

### HUD

- `ShowHUD`: Show the radio display widget on the HUD.
- `ShowWithoutEquippedHUD`: Set to `true` to show the widget with no helmet HUD equipped. Set to `false` to require HUD gear.
- `AutoHideWhenOff`: Hide the widget when the radio is off.
- `TransitionDuration`: Time in seconds to show "RADIO ON" or "RADIO OFF" status text.
- `FadeDuration`: Fade transition time in seconds.

### VolumeSlider

- `ShowVolumeSlider`: Show the volume progress bar when you adjust volume.
- `SliderHideDelay`: Time in seconds before the volume slider fades out.
- `SliderWidth`: Width of the volume progress bar in pixels.
- `SliderHeight`: Height of the volume progress bar in pixels.

### Text

- `FontSize`: Text size of the song title and status.
- `EnableMarquee`: Scroll long song titles horizontally.
- `MaxVisibleCharacters`: Maximum character width of the marquee window.
- `MarqueeSpeed`: Characters shifted per second.

### Icon

- `ShowIcon`: Show the musical note icon next to the song title.
- `IconSize`: Dimensions of the icon in pixels.
- `IconSpacing`: Gap between the icon and text in pixels.

### Position

- `Anchor`: Screen anchor position (`BottomLeft`, `Center`, `TopLeft`, `TopRight`, `BottomRight`, `TopCenter`, `BottomCenter`).
- `OffsetX`: Horizontal pixel offset from the anchor position.
- `OffsetY`: Vertical pixel offset from the anchor position.
