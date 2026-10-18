Callback Appmodel example
=========================

Implements SDL3's callback based application model in Odin.

The control flow goes like this:

```
+ Odin main
|
+---+> sdl3.RunApp (external)
    |
    +---+> SDL_AppMain
        |
        +---+> sdl3.EnterAppMainCallbacks(SDL_AppInit, SDLAppIterate, SDL_AppEvent, SDL_AppQuit) (external)
            |
            +---> SDL_AppInit
            |
            +---> SDL_AppIterate
            +---> SDL_AppEvent
            +---> SDL_AppEvent
            +---> SDL_AppIterate
            +---> SDL_AppIterate
            ...
			|
            +---> SDL_AppQuit
            |
        +---+
        |
    +---+
    |
+---+
|
+
```

The rationale behind this application model is that newer platforms, especially mobile, diverge
from the classic "program has one main function and when it returns, it's over" application model.
This gives the OS more control over the resources an application uses, which can be important
for power management and multitasking.

The purpose behind this architecture is to keep the application's main driver code the same
between different platforms.
