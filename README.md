# Simple game engine with cpu rendering implemented in zig

Write a software rendering engine and explore some zig at the same time.

# Links
  * [Markdown](https://guides.github.com/features/mastering-markdown)
  * [Documentation](https://ziglang.org/documentation/master)
  * [Zig Github](https://github.com/ziglang/zig)

# Tasks
  
### Debug
  - [ ] Server, host and support commands and debug data streaming

### Profiler
  - [x] Simple wallclock based profiler intended to be used for inspecting large sections like:
    * UI
    * Game
    * Rendering
    * Input
    * System

  - [ ] Add support for allocating sample data _(aka. explore using allocators)_
    - [ ] Threaded write?
    - [ ] Add Per Frame Profile data streaming 
  
### Systems
  - [ ] Threaded Job/Tasks  

### I/O
  - [ ] Mesh Loading
  - [ ] Image loading

### Core
  - [x] Matrix [Mat44f](src/core/matrix.zig)
  - [x] Vector [Vec4f](src/core/vector.zig)

### Runtime Libraries
  - [ ] Game Logic
  - [ ] Core
  - [ ] System
  - [ ] Profiler/Debug

### Rendering
  - [x] Basic triangle and mesh rasterizer
  - [ ] Text Rendering
  - [ ] Ui Render texture different from world
  - [ ] Depth Buffer
  - [ ] Backface culling
  - [ ] Wrap render buffer
  - [ ] Shaders
  - [ ] Texture Mapping
  - [ ] Explore raytracing
  - [ ] Height Map Terrain Rendering
  - [ ] Parallel Rendering using Job/Task system

### Unit Testing
  - [ ] [Mat44f](src/core/matrix.zig)
  - [ ] [Vec4f](src/core/vector.zig)

  