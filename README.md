# Aseprite Triangle Color Picker

![Screen Cap](screenCap0.png)

This is a triangle color picker made with the [Aseprite](https://www.aseprite.org/) [scripting API](https://www.aseprite.org/docs/scripting/). It is intended for use with Aseprite version 1.3 or newer.

## Download

To download this script, click on the green Code button above, then select Download Zip. You can also click on the `aseTriPicker.lua` file. Beware that some browsers will append a `.txt` file format extension to script files on download. Aseprite will not recognize the script until this is removed and the original `.lua` extension is used. There can also be issues with copying and pasting. Be sure to click on the Raw file button; do not copy the formatted code.

## Usage

To use this script, open Aseprite. In the menu bar, go to `File > Scripts > Open Scripts Folder`. Move the Lua script into the folder that opens. Return to Aseprite; go to `File > Scripts > Rescan Scripts Folder`. The script should now be listed under `File > Scripts`. Select `aseTriPicker.lua` to launch the dialog.

If an error message in Aseprite's console appears, check if the script folder is on a file path that includes characters beyond ASCII, such as 'é' (e acute) or 'ö' (o umlaut).

A hot key can be assigned to the script by going to `Edit > Keyboard Shortcuts`. The search input box in the top left of the shortcuts dialog can be used to locate the script by its file name.

The dialog can be closed with `Alt+X`. The foreground color can be retrieved with `Alt+F`; the background color, with `Alt+B`. `Alt+A` will pick a color from the sprite canvas at the cursor position. When the default theme font is used, these shortcuts will be underlined.

When the dialog canvas has focus, left click will change the foreground color; right click will adjust the background color. Clicking on the swatches in the bottom-left corner will swap the fore and background color. Clicking and dragging within the hue ring will change the unquantized hue. When the `Shift` key is held down, this change happens in 15 degree steps. Pressing the arrow left and right keys will nudge the hue. Pressing the arrow up and down keys will nudge the value. Holding `Alt` while pressing the up and down keys will nudge the saturation.

![Expanded Screen Cap](screenCap1.png)

When the picker is wider than it is high, it will show text information about the color. Hue is expressed in degrees; other data, in percentages. When a color's saturation is zero, its hue is undefined. When its value is zero, both hue and saturation are undefined. This is easier to understand by visualizing the HSV model as an upside-down cone, where black is at the tip.

![Quantized Screen Cap](screenCap2.png)

Colors can be quantized to a bit depth in RGB using the sliders beneath the canvas. Quantization will lead to significant hue shift between colors within the same shading triangle.

![Lock Tri](screenCap3.png)

The triangle's rotation can be locked by clicking the check box. A white reticle will indicate the current hue position.

## Caveat

Ultimately, the [HSV](https://en.wikipedia.org/wiki/HSL_and_HSV#Disadvantages) color representation is deeply flawed. Neither this color picker, nor HSV in general, should be used to create harmonious colors or determine shades of a hue. I would encourage readers to research alternatives like [CIE LAB](https://en.wikipedia.org/wiki/CIELAB_color_space), [SRLAB2](https://www.magnetkern.de/srlab2.html), [OK LAB](https://bottosson.github.io/posts/oklab/), [HSLuv](https://www.hsluv.org/) or [Okhsl](https://bottosson.github.io/posts/colorpicker/). An SRLAB2 picker is available at [AsepriteAddons](https://github.com/behreajj/AsepriteAddons); an Okhsl picker can be found [here](https://github.com/behreajj/asepriteokhsl).

*This script is intended for use in the standard RGB (sRGB) color space only.* Colors may appear washed out when using other color spaces, such as Display P3 or Adobe RGB.

## Modification

To modify these scripts, see Aseprite's [API Reference](https://github.com/aseprite/api). There is also a [type definition](https://github.com/behreajj/aseprite-type-definition) for use with VS Code and the [Lua Language Server extension](https://github.com/LuaLS/lua-language-server).

## Issues

This script was tested in Aseprite version 1.3.9 on Windows 10. Its user interface elements were tested with 100% screen scaling and 200% UI scaling. Please report issues in the issues section on Github.