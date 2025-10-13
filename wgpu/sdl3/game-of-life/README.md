# Conway's Game of Life - Architecture Documentation

## Overview

This is a GPU-accelerated implementation of Conway's Game of Life using WebGPU, written in Odin. The application runs on both desktop (SDL3) and web (WebAssembly) platforms with a unified codebase.

> **Note:** This is based on the SDL3 trinagle example and a port of the tutorial you can find here: https://codelabs.developers.google.com/your-first-webgpu-app#0. The original tutorial used JavaScript.

**Key Features:**
- 32×32 cell grid (1,024 cells)
- 5 Hz simulation update rate (200ms intervals)
- Compute shader implementation of Game of Life rules
- Ping-pong buffer architecture for efficient GPU updates
- Simple, direct architecture following Odin idioms

**Learning Goals:**
- Using Odin to implement something previously done in JavaScript
- Working with Odin WGPU bindings: https://pkg.odin-lang.org/vendor/wgpu/
- Platform abstraction using Odin's build tags

---
![](img/conways-gol.png)

---

## Project Structure

The codebase follows a simple 3-file structure:

```mermaid
graph LR
    A[main.odin] --> B[os_desktop.odin<br/>#+build !js]
    A --> C[os_web.odin<br/>#+build js]
    
    D[shaders/] --> E[compute.wgsl]
    D --> F[render.wgsl]
    
    style A fill:#4CAF50,color:#fff
    style B fill:#FF9800,color:#fff
    style C fill:#2196F3,color:#fff
    style D fill:#9C27B0,color:#fff
```

### File Overview

| File | LOC | Purpose |
|------|-----|---------|
| `main.odin` | 466 | Core GPU logic, state management, rendering |
| `os_desktop.odin` | 104 | SDL3 platform layer (synchronous) |
| `os_web.odin` | 122 | WASM platform layer (asynchronous) |
| **Total** | **692** | **Complete application** |

### Build Tags

Odin's build tag system selects the appropriate platform file at compile time:

- **Desktop build:** `odin build .` → Uses `os_desktop.odin` (excludes `os_web.odin`)
- **Web build:** `odin build . -target:js_wasm32` → Uses `os_web.odin` (excludes `os_desktop.odin`)

---

## Architecture Overview

```mermaid
flowchart TD
    Start([Program Start]) --> Init[main.odin::main]
    Init --> OSInit[os_init<br/>Platform-specific]
    OSInit --> GPUInit[init_gpu<br/>Create instance & surface]
    GPUInit --> ReqAdapter[os_request_adapter_and_device<br/>Platform callbacks]
    
    ReqAdapter --> |Desktop: Sync| DesktopAdapter[on_adapter_sync]
    ReqAdapter --> |Web: Async| WebAdapter[on_adapter callback]
    
    DesktopAdapter --> DesktopDevice[on_device_sync]
    WebAdapter --> WebDevice[on_device callback]
    
    DesktopDevice --> Complete[complete_gpu_init]
    WebDevice --> Complete
    
    Complete --> CreatePipelines[Create Pipelines<br/>Render & Compute]
    CreatePipelines --> CreateBuffers[Create Buffers<br/>Vertex, Uniform, Storage]
    CreateBuffers --> Run[os_run<br/>Start event loop]
    
    Run --> |Desktop| DesktopLoop[SDL Event Loop<br/>Calculate dt]
    Run --> |Web| WebLoop[Browser step<br/>Receives dt]
    
    DesktopLoop --> Frame[frame]
    WebLoop --> Frame
    
    Frame --> Update[update_simulation<br/>Accumulate dt]
    Update --> Compute{Time for<br/>update?}
    Compute --> |Yes| ComputePass[run_compute_pass<br/>Execute shader]
    Compute --> |No| Skip[Skip compute]
    ComputePass --> Render[Render Pass<br/>Draw cells]
    Skip --> Render
    Render --> Present[Present Frame]
    Present --> |Loop| DesktopLoop
    Present --> |Loop| WebLoop
    
    style Init fill:#4CAF50,color:#fff
    style Complete fill:#4CAF50,color:#fff
    style DesktopLoop fill:#FF9800,color:#fff
    style WebLoop fill:#2196F3,color:#fff
    style Frame fill:#9C27B0,color:#fff
```

---

## main.odin - Core Application Logic

The main file contains all GPU-related code and the application state.

### Key Components

#### 1. Configuration Constants
```odin
WIDTH :: 512                            // Window width
HEIGHT :: 512                           // Window height
GRID_SIZE :: 32                         // 32×32 grid
WORKGROUP_SIZE :: 8                     // Compute shader workgroup size
UPDATE_INTERVAL_MILLISECONDS :: 200.0   // 5 Hz update rate
```

#### 2. Application State
```odin
App_State :: struct {
    ctx: runtime.Context
    
    // WebGPU core
    instance, surface, adapter, device: wgpu.*
    queue: wgpu.Queue
    config: wgpu.SurfaceConfiguration
    
    // Pipelines & layouts
    pipeline_layout, bind_group_layout: wgpu.*
    render_module, compute_module: wgpu.ShaderModule
    render_pipeline: wgpu.RenderPipeline
    compute_pipeline: wgpu.ComputePipeline
    
    // Buffers
    vertex_buffer, uniform_buffer: wgpu.Buffer
    cell_state_storage: [2]wgpu.Buffer  // Ping-pong
    bind_groups: [2]wgpu.BindGroup
    
    // Simulation
    step_index: u64
    did_compute, do_update: bool
    last_tick: time.Tick
    accumulator: time.Duration
}
```

#### 3. Initialization Flow

```mermaid
sequenceDiagram
    participant M as main()
    participant OS as os_*
    participant GPU as GPU Init
    
    M->>OS: os_init()
    M->>GPU: init_gpu()
    GPU->>GPU: Create instance
    GPU->>OS: os_get_surface()
    OS-->>GPU: Surface
    GPU->>OS: os_request_adapter_and_device()
    
    Note over OS: Platform-specific async/sync
    
    OS->>GPU: complete_gpu_init(device)
    GPU->>GPU: create_bind_group_layout()
    GPU->>GPU: create_render_pipeline()
    GPU->>GPU: create_compute_pipeline()
    GPU->>GPU: create_buffers_and_bind_groups()
    GPU->>OS: os_run()
```

#### 4. Pipeline Creation

**Render Pipeline:**
- Vertex shader positions cell instances in grid
- Fragment shader colors cells (green/black)
- Reads from storage buffer to determine cell state

**Compute Pipeline:**
- Implements Conway's Game of Life rules
- Reads from one storage buffer (current state)
- Writes to another storage buffer (next state)
- Runs at 5 Hz (every 200ms)

```mermaid
graph LR
    A[Vertex Buffer<br/>Cell Quad] --> B[Render Pipeline]
    C[Uniform Buffer<br/>Grid Size] --> B
    D[Storage Buffer A<br/>Cell States] --> B
    D --> E[Compute Pipeline]
    E --> F[Storage Buffer B<br/>New States]
    F --> B
    
    style B fill:#4CAF50,color:#fff
    style E fill:#9C27B0,color:#fff
```

#### 5. Buffer Architecture (Ping-Pong)

```mermaid
graph TD
    subgraph "Frame N"
        A[Storage Buffer A<br/>Current State] --> C[Compute Shader]
        C --> B[Storage Buffer B<br/>Next State]
        B --> R1[Render Pipeline<br/>Read from B]
    end
    
    subgraph "Frame N+1"
        B2[Storage Buffer B<br/>Current State] --> C2[Compute Shader]
        C2 --> A2[Storage Buffer A<br/>Next State]
        A2 --> R2[Render Pipeline<br/>Read from A]
    end
    
    R1 -.-> B2
    R2 -.-> A
    
    style C fill:#9C27B0,color:#fff
    style C2 fill:#9C27B0,color:#fff
```

**Key insight:** 
- Compute writes to buffer `(step + 1) % 2`
- Render reads from buffer `(step + 1) % 2` (the latest computed state)

#### 6. Simulation Timing

```mermaid
flowchart LR
    A[Frame Called] --> B[update_simulation dt]
    B --> C{accumulator >= 200ms?}
    C --> |Yes| D[Set do_update = true<br/>Reset accumulator]
    C --> |No| E[Set do_update = false]
    D --> F[run_compute_pass]
    E --> F
    F --> G{do_update?}
    G --> |Yes| H[Execute Compute Shader<br/>Increment step_index]
    G --> |No| I[Skip compute]
    H --> J[Render Pass]
    I --> J
```

**Desktop timing:** `dt` calculated using `SDL.GetPerformanceCounter()`  
**Web timing:** `dt` provided by browser (seconds since last frame)

#### 7. Frame Rendering

```odin
frame :: proc "c" (dt: f32) {
    update_simulation(dt)
    
    // Acquire surface texture
    // Create command encoder
    
    run_compute_pass(encoder)  // Conditional based on timing
    
    // Render pass
    // - Clear to dark blue
    // - Bind render pipeline
    // - Bind group: (step + 1) % 2  (read latest)
    // - Draw instances: GRID_SIZE * GRID_SIZE
    
    // Submit and present
    
    if did_compute {
        step_index += 1
    }
}
```

---

## os_desktop.odin - SDL3 Platform Layer

Provides synchronous initialization and blocking event loop for desktop platforms.

### Key Components

```mermaid
flowchart TD
    A[os_init] --> B[SDL.Init]
    B --> C[SDL.CreateWindow]
    
    D[os_get_surface] --> E[sdl3glue.GetSurface]
    
    F[os_get_framebuffer_size] --> G[SDL.GetWindowSizeInPixels]
    
    H[os_request_adapter_and_device] --> I[wgpu.InstanceRequestAdapter<br/>callback: on_adapter_sync]
    I --> J[on_adapter_sync<br/>fires immediately]
    J --> K[wgpu.AdapterRequestDevice<br/>callback: on_device_sync]
    K --> L[on_device_sync<br/>fires immediately]
    L --> M[complete_gpu_init]
    
    N[os_run] --> O[SDL Event Loop]
    O --> P[Calculate dt<br/>SDL.GetPerformanceCounter]
    P --> Q[SDL.PollEvent]
    Q --> R{Event Type}
    R --> |QUIT| S[Exit]
    R --> |KEY_DOWN ESCAPE| S
    R --> |WINDOW_RESIZED| T[resize]
    R --> |Continue| U[frame dt]
    T --> U
    U --> P
    S --> V[cleanup<br/>SDL.DestroyWindow<br/>SDL.Quit]
    
    style A fill:#FF9800,color:#fff
    style N fill:#FF9800,color:#fff
    style J fill:#4CAF50,color:#fff
    style L fill:#4CAF50,color:#fff
```

### Synchronous Callbacks

On desktop, WebGPU callbacks fire **immediately** (synchronously):

```odin
wgpu.InstanceRequestAdapter(...)
// Callback fires before this line executes
// adapter is already available
```

### Event Loop

```odin
os_run :: proc() {
    last := SDL.GetPerformanceCounter()
    
    for running {
        now = SDL.GetPerformanceCounter()
        dt = f32((now - last) * 1000) / f32(SDL.GetPerformanceFrequency())
        last = now
        
        for SDL.PollEvent(&event) {
            #partial switch event.type {
            case .QUIT: running = false
            case .KEY_DOWN:
                if event.key.scancode == .ESCAPE {
                    running = false
                }
            case .WINDOW_RESIZED: resize()
            }
        }
        
        frame(dt)  // dt in milliseconds
    }
}
```

---

## os_web.odin - WASM Platform Layer

Provides asynchronous initialization and browser-driven event loop for web platforms.

### Key Components

```mermaid
flowchart TD
    A[os_init] --> B[js.add_window_event_listener<br/>Resize]
    
    C[os_get_surface] --> D[wgpu.InstanceCreateSurface<br/>Canvas selector: #wgpu-canvas]
    
    E[os_get_framebuffer_size] --> F[js.get_bounding_client_rect<br/>body]
    F --> G[Apply device_pixel_ratio]
    
    H[os_request_adapter_and_device] --> I[wgpu.InstanceRequestAdapter<br/>inline callback: on_adapter]
    I -.Async.-> J[on_adapter<br/>fires when ready]
    J --> K[wgpu.AdapterRequestDevice<br/>inline callback: on_device]
    K -.Async.-> L[on_device<br/>fires when ready]
    L --> M[complete_gpu_init]
    
    N[os_run] --> O[Set device_ready = true]
    
    P[step dt<br/>@export] --> Q{device_ready?}
    Q --> |No| R[return true]
    Q --> |Yes| S[frame dt]
    S --> T[return true]
    
    U[size_callback] --> V{device_ready?}
    V --> |Yes| W[resize]
    V --> |No| X[return]
    
    style A fill:#2196F3,color:#fff
    style N fill:#2196F3,color:#fff
    style P fill:#2196F3,color:#fff
    style J fill:#4CAF50,color:#fff
    style L fill:#4CAF50,color:#fff
```

### Asynchronous Callbacks

On web, WebGPU callbacks fire **asynchronously** (when browser completes operation):

```odin
wgpu.InstanceRequestAdapter(...)
// Function returns immediately
// Callback fires later (100-500ms typical)
```

**Critical:** Callbacks must be defined **inline** in the same scope for WASM:

```odin
os_request_adapter_and_device :: proc() {
    wgpu.InstanceRequestAdapter(
        state.instance,
        &{compatibleSurface = state.surface},
        {callback = on_adapter},
    )
    
    // Define callback inline
    on_adapter :: proc "c" (...) {
        context = state.ctx
        // ... adapter handling
        wgpu.AdapterRequestDevice(..., {callback = on_device})
        
        // Nested inline callback
        on_device :: proc "c" (...) {
            context = state.ctx
            // ... device handling
            complete_gpu_init(device)
        }
    }
}
```

### Browser Integration

```mermaid
sequenceDiagram
    participant B as Browser
    participant W as WASM Module
    participant G as GPU
    
    B->>W: Load & Initialize
    W->>G: Request Adapter
    Note over W,G: Async - returns immediately
    
    G-->>W: on_adapter callback
    W->>G: Request Device
    Note over W,G: Async - returns immediately
    
    G-->>W: on_device callback
    W->>W: complete_gpu_init
    W->>W: os_run (set ready flag)
    
    loop 60 FPS
        B->>W: step(dt)
        W->>W: frame(dt)
        W-->>B: return true
    end
```

### Exported Functions

```odin
@(export)
step :: proc(dt: f32) -> bool {
    context = state.ctx
    
    if !device_ready {
        return true  // Still initializing
    }
    
    frame(dt)  // dt in seconds
    return true
}

@(fini)
cleanup_on_exit :: proc "contextless" () {
    cleanup()
    js.remove_window_event_listener(.Resize, nil, size_callback)
}
```

---

## Shader Architecture

### compute.wgsl - Game of Life Rules

```mermaid
flowchart LR
    A[Invocation ID<br/>x, y] --> B[Read 8 Neighbors<br/>from cellStateIn]
    B --> C[Count Active<br/>Neighbors]
    C --> D{Current Cell<br/>Active?}
    D --> |Yes| E{neighbors == 2<br/>or 3?}
    D --> |No| F{neighbors == 3?}
    E --> |Yes| G[Write 1<br/>cellStateOut]
    E --> |No| H[Write 0<br/>cellStateOut]
    F --> |Yes| G
    F --> |No| H
    
    style C fill:#9C27B0,color:#fff
    style G fill:#4CAF50,color:#fff
    style H fill:#f44336,color:#fff
```

**Workgroup Configuration:**
- Size: 8×8 (64 threads per workgroup)
- Dispatch: 4×4 workgroups for 32×32 grid
- Total: 1,024 parallel executions

**Bindings:**
- `@binding(0)`: Uniform buffer (grid size)
- `@binding(1)`: Read-only storage (current cell states)
- `@binding(2)`: Storage (output cell states)

### render.wgsl - Cell Visualization

```mermaid
flowchart TD
    A[Instance ID] --> B[Calculate Grid Position<br/>x = id % GRID_SIZE<br/>y = id / GRID_SIZE]
    B --> C[Read Cell State<br/>cellStateIn instance]
    C --> D[Scale Vertex Position<br/>by 1/GRID_SIZE]
    D --> E[Translate to Grid Cell<br/>offset by x, y]
    E --> F[Output Position]
    
    G[Fragment Shader] --> H{Cell Active?}
    H --> |Yes| I[Green: 0, 0.6, 0]
    H --> |No| J[Black: 0, 0, 0]
    
    style F fill:#4CAF50,color:#fff
    style I fill:#4CAF50,color:#fff
    style J fill:#424242,color:#fff
```

**Vertex Shader:**
- Input: Cell quad vertices (-0.8 to 0.8)
- Instance rendering: Draw GRID_SIZE² instances
- Each instance represents one cell

**Fragment Shader:**
- Simple color selection based on cell state
- Active cells: Green `(0, 0.6, 0)`
- Inactive cells: Black `(0, 0, 0)`

---

## Platform Differences

### Desktop (SDL3)

| Aspect | Implementation |
|--------|----------------|
| **Windowing** | SDL3 native window |
| **Event Loop** | Blocking `SDL.PollEvent()` |
| **Frame Timing** | Manual via `SDL.GetPerformanceCounter()` |
| **WebGPU Init** | Synchronous callbacks |
| **Delta Time** | Milliseconds (calculated) |
| **Exit Handling** | Window close or Escape key |

### Web (WASM)

| Aspect | Implementation |
|--------|----------------|
| **Windowing** | HTML5 Canvas (`#wgpu-canvas`) |
| **Event Loop** | Browser `requestAnimationFrame` calls `step()` |
| **Frame Timing** | Provided by browser |
| **WebGPU Init** | Asynchronous callbacks (inline) |
| **Delta Time** | Seconds (from browser) |
| **Exit Handling** | Browser tab close |

### Callback Timing Diagram

```mermaid
sequenceDiagram
    participant C as Caller
    participant W as WebGPU
    participant CB as Callback
    
    Note over C,CB: DESKTOP (Synchronous)
    C->>W: RequestAdapter
    W->>CB: Callback fires immediately
    CB->>C: Returns to caller
    Note over C: Adapter ready here
    
    Note over C,CB: WEB (Asynchronous)
    C->>W: RequestAdapter
    W-->>C: Returns immediately
    Note over C: Adapter NOT ready yet
    Note over W: Browser processes...
    W->>CB: Callback fires later
    Note over CB: Adapter ready NOW
```

---

## Build System

### Desktop Build

```bash
odin build . -out:game-of-life -vet -strict-style -vet-tabs -disallow-do -warnings-as-errors
./sdl3-Game-of-life
```

**What happens:**
1. Compiler includes `main.odin` and `os_desktop.odin`
2. `os_web.odin` excluded via `#+build js` tag
3. Links SDL3 and WebGPU native libraries
4. Creates native executable

### Web Build

```bash
odin build . -target:js_wasm32 -out:web/game_of_life.wasm
```

**What happens:**
1. Compiler includes `main.odin` and `os_web.odin`
2. `os_desktop.odin` excluded via `#+build !js` tag
3. Generates WebAssembly module
4. Exports `step()` function for browser

### Build Tags Explanation

```odin
// os_desktop.odin
#+build !js        // Include when NOT building for JavaScript
package main

// os_web.odin
#+build js         // Include ONLY when building for JavaScript
package main
```

Build tags are **file-level** in Odin - you cannot use them inline within functions.

---

## Data Flow

### Initialization Flow

```mermaid
graph TD
    A[main] --> B[os_init]
    B --> C[init_gpu]
    C --> D[Create instance]
    D --> E[os_get_surface]
    E --> F[os_request_adapter_and_device]
    
    F --> G{Platform?}
    G --> |Desktop| H[Sync callbacks]
    G --> |Web| I[Async callbacks]
    
    H --> J[complete_gpu_init]
    I --> J
    
    J --> K[Configure surface]
    K --> L[create_bind_group_layout]
    L --> M[create_render_pipeline]
    M --> N[create_compute_pipeline]
    N --> O[create_buffers_and_bind_groups]
    O --> P[Initialize with random cells]
    P --> Q[os_run]
    
    style A fill:#4CAF50,color:#fff
    style J fill:#4CAF50,color:#fff
    style Q fill:#FF9800,color:#fff
```

### Frame Flow

```mermaid
graph TD
    A[frame dt] --> B[update_simulation]
    B --> C[accumulator += dt]
    C --> D{accumulator >= 200ms?}
    D --> |Yes| E[do_update = true<br/>accumulator = 0]
    D --> |No| F[do_update = false]
    
    E --> G[Get surface texture]
    F --> G
    G --> H[Create command encoder]
    
    H --> I[run_compute_pass]
    I --> J{do_update?}
    J --> |Yes| K[Begin compute pass]
    J --> |No| L[Skip]
    
    K --> M[Set compute pipeline]
    M --> N[Bind group: step % 2]
    N --> O[Dispatch workgroups]
    O --> P[did_compute = true]
    
    P --> Q[Begin render pass]
    L --> Q
    Q --> R[Clear to dark blue]
    R --> S[Set render pipeline]
    S --> T[Bind group: step+1 % 2]
    T --> U[Set vertex buffer]
    U --> V[Draw GRID_SIZE²]
    V --> W[End render pass]
    
    W --> X[Submit & Present]
    X --> Y{did_compute?}
    Y --> |Yes| Z[step_index++]
    Y --> |No| AA[Keep step_index]
    
    style E fill:#4CAF50,color:#fff
    style K fill:#9C27B0,color:#fff
    style P fill:#9C27B0,color:#fff
    style Z fill:#4CAF50,color:#fff
```

---

## Performance Characteristics

### GPU Workload

| Operation | Frequency | GPU Load |
|-----------|-----------|----------|
| **Compute Shader** | 5 Hz | 1,024 threads (32×32 grid) |
| **Render Pass** | 60 FPS | 1,024 instances, 6 vertices each |
| **Buffer Updates** | 0 Hz | No CPU→GPU transfers after init |

### Memory Usage

| Resource | Size | Count | Total |
|----------|------|-------|-------|
| **Vertex Buffer** | 48 bytes | 1 | 48 B |
| **Uniform Buffer** | 8 bytes | 1 | 8 B |
| **Storage Buffers** | 4 KB | 2 | 8 KB |
| **Bind Groups** | - | 2 | - |
| **Pipelines** | - | 2 | - |

**Total GPU memory:** ~8 KB (excluding shader bytecode and pipeline state)

### CPU Load

| Platform | Per Frame | Notes |
|----------|-----------|-------|
| **Desktop** | Minimal | Event polling, dt calculation |
| **Web** | Minimal | Browser calls `step()` |

**Key insight:** After initialization, all simulation logic runs on GPU. CPU only submits command buffers.

---

## Troubleshooting

### Desktop Issues

**Problem:** Window opens but cells don't update  
**Solution:** Check that delta time is being calculated (not passing `0`)

**Problem:** Window doesn't open  
**Solution:** Ensure SDL3 is installed and linked correctly

**Problem:** WebGPU errors  
**Solution:** Check that your GPU supports WebGPU (Metal on macOS, D3D12 on Windows, Vulkan on Linux)

### Web Issues

**Problem:** Black screen, no errors  
**Solution:** Check browser console - likely async callbacks not firing

**Problem:** "WebGPU not supported"  
**Solution:** Use Chrome/Edge with WebGPU enabled, serve over `http://127.0.0.1` (not `file://` or IPV6 [::]: <port>)

**Problem:** Callbacks never fire  
**Solution:** Ensure callbacks are defined **inline** in the same scope as registration

**Problem:** Canvas size wrong  
**Solution:** Check `device_pixel_ratio` and canvas CSS

### Common Issues

**Problem:** Compilation errors with build tags  
**Solution:** Build tags must be at top of file, before `package` declaration

**Problem:** Linking errors  
**Solution:** Ensure `vendor:wgpu`, `vendor:sdl3` are available in your Odin installation

---

## Future Enhancements

Potential improvements while maintaining simplicity:

1. **Interactive Controls**
   - Mouse click to toggle cells
   - Space bar to pause/resume
   - R key to randomize grid (matchin the Win32 example)

2. **Adjustable Parameters**
   - Grid size selection (16×16, 32×32, 64×64)
   - Update rate slider
   - Color themes

3. **Patterns**
   - Load predefined patterns (glider, blinker, etc.)
   - Save/load grid states

4. **Performance**
   - Larger grids (128×128, 256×256)
   - Multiple compute passes per frame
   - Benchmarking mode

**Constraint:** Keep 3-file structure, avoid over-abstraction

---

## References

- **Original Tutorial:** https://codelabs.developers.google.com/your-first-webgpu-app
- **Odin Language:** https://odin-lang.org
- **Odin WGPU Bindings:** https://pkg.odin-lang.org/vendor/wgpu/
- **SDL3:** https://wiki.libsdl.org/SDL3/
- **WebGPU Spec:** https://gpuweb.github.io/gpuweb/
- **Conway's Game of Life:** https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life

---

## License

This code is part of the Odin examples repository.

---

*Last updated: October 13, 2025*  

