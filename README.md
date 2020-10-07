# Simple game engine with cpu rendering implemented in zig

Write a software rendering engine and explore some zig at the same time.

# Links
  * [Markdown](https://guides.github.com/features/mastering-markdown)
  * [Documentation](https://ziglang.org/documentation/master)
  * [Zig Github](https://github.com/ziglang/zig)

# Tasks
  
### Debug
  - [ ] Server, host and support commands and debug data streaming
  - [ ] Allocator based game data partitioning 
    - [ ] Allow for pages of data to be streamed, needs pointer normalization

### Profiler
  - [x] Simple wallclock based profiler intended to be used for inspecting large sections like:
    * UI
    * Game
    * Rendering
    * Input
    * System

    - [ ] Double buffer profiler to display last frame while rendering/updating next frame
    - [ ] Threaded write to disk?

  
### Systems
  - [ ] Threaded Job/Tasks  

### I/O
  - [ ] Mesh Loading
    - [x] Basic mesh only, text .OBJ import 
    - [ ] Material import from .MTL files
  - [ ] Image loading
    - [x] .TGA uncompressed RGB8,Grayscale8


### Core
  - [ ] Move main function to game files, use `engine` as import
  - [ ] Perlin Noise 
  - [x] Matrix [Mat44f](src/core/matrix.zig)
  - [x] Vector [Vec4f](src/core/vector.zig)


### Rendering
  - [ ] Ui Render texture different from world
  - [ ] Text Rendering
  - [ ] Profiler Rendering
  
  
#### Done
  - [x] Basic triangle and mesh rasterizer
  - [x] Depth Buffer
  - [x] Backface culling
  - [x] Wrap render buffer
  - [x] Shaders
  - [x] Texture Mapping

#### Crazy/Fun? Ideas
  - [ ] Voxel based world
  - [ ] Explore raytracing
  - [ ] Height Map Terrain Rendering
  - [ ] Parallel Rendering using Job/Task system


### Runtime Libraries?
  - [ ] Game Logic
  - [ ] Core
  - [ ] System
  - [ ] Profiler/Debug


### Unit Testing
  - [ ] [Mat44f](src/core/matrix.zig)
  - [ ] [Vec4f](src/core/vector.zig)


  