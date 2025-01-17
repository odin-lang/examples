# Vulkan triangle example

By laytan, source: https://gist.github.com/laytan/ba57af3e5a59ab5cb2fca9e25bcfe262

Compile and run using:
```
odin run .
```

This example comes with pre-compiled shaders. During compilation the shaders will be loaded from `vert.spv` and `frag.spv`.

If you make any changes to the shader source files (`shader.vert` or `shader.frag`), then you must recompile them using `glslc`:
```
glslc shader.vert -o vert.spv
glslc shader.frag -o frag.spv
```

`glslc` is part of the Vulkan SDK, which you can find here: https://vulkan.lunarg.com/sdk/home

This example uses glfw for window management.

![image](https://github.com/user-attachments/assets/c87b957c-8b1c-4c07-8b3e-b31fa4a98a53)
