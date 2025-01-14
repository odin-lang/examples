# Vulkan triangle example

By laytan, from: https://gist.github.com/laytan/ba57af3e5a59ab5cb2fca9e25bcfe262

You must compile the shaders before compiling this program:
```
glslc shader.vert -o vert.spv
glslc shader.frag -o frag.spv
```

glslc is part of shaderc, which you can find here: https://github.com/google/shaderc

This example uses glfw for window management.