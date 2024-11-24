Godot-Water-Shader-Prototype
============================
This is a maintained fork of the [original work](https://github.com/Platinguin/Godot-Water-Shader-Prototype) by @Platinguin.

![Screen capture](https://raw.githubusercontent.com/Flarkk/Godot-Water-Shader-Prototype/master/video/video.gif)

#### Latest versions
- **October 2024** [(tag)](https://github.com/Flarkk/Godot-Water-Shader-Prototype/tree/v4.3) : bring compatibility with Godot 4

#### Release Notes
##### October 2024
- Fixed syntax errors in GDScript and GLSL code subsequent to the migration from Godot 3 to 4
- Fixed uninitialized variable in camera lense shader causing the entire viewport to flicker
- Fixed banding in ocean shader due to gradient texture having swapped UVs in Godot 4
- Migrated the viewport-based flow map generator to a compute shader
- Fixed compatibility issues with Reverse-z in the ocean visual shader
- Fixed GLSL's `smoothstep()` usages where `edge0 > edge1` which is undefined behavior in Vulkan
- Fixed various artifacts in ocean visual shader (among others : changes in linear / sRGB conversions, remove usage of `fract()` for UV coordinates causing texture filtering glitches, `light()` function not writing specular light to `SPECULAR_LIGHT`)
- Improved shaders' code readability by simplifying some expressions
