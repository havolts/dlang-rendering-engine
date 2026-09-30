// renderengine/source/main.d
module main;


import mesh;
import renderer;
import texture;
import types;
import node;
import camera;
import meshloader;

import core.atomic;
import core.thread;
import core.time;
import std.math;
import std.stdio;
import std.string : fromStringz;

import sdl;
import sdl.error;
import sdl.gpu;

void main()
{
    if(!SDL_Init(SDL_INIT_VIDEO))
    {
        writeln("SDL_Init failed: ", SDL_GetError());
    }

    const(char) * title = "My SDL3 Window";
    SDL_Window* window = SDL_CreateWindow(title, 600, 600, SDL_WindowFlags.SDL_WINDOW_MAXIMIZED);
    SDL_ShowWindow(window);
    if (window is null)
    {
        writeln("SDL_CreateWindow failed: ", SDL_GetError());
        SDL_Quit();
        return;
    }

    SDL_GPUShaderFormat formats = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_MSL | SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_METALLIB | SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_DXIL | SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_SPIRV;
    SDL_GPUDevice* device = SDL_CreateGPUDevice(formats, false, null);
    if(device is null)
    {
        writeln("SDL_CreateGPUDevice failed: ", fromStringz(SDL_GetError()));
        SDL_Quit();
        return;
    }

    if(!SDL_ClaimWindowForGPUDevice(device, window))
    {
        writeln("SDL_ClaimWindowForGPUDevice failed: ", SDL_GetError());
        SDL_Quit();
        return;
    }

    Renderer renderer = new Renderer(device, window, "shader.vert.msl", "shader.frag.msl");
    Node[] nodes;

    MeshLoader loader = new MeshLoader();

    Mesh cube = loader.loadObj("source/assets/textured_cube.obj", renderer);
    nodes ~= new Node(device, cube);
    Camera camera = new Camera();

    void Start()
    {
        camera.position.y = 5f;
        camera.position.z = 10f;

        camera.rotation.x = -1f;
    }

    void Update(float delta)
    {

    }

    Start();
    SDL_Event event;
    bool running = true;
    while (running)
    {
        while (SDL_PollEvent(&event))
        {
            if (event.type == SDL_EventType.SDL_EVENT_QUIT)
            {
                running = false;
            }
        }
        renderer.renderFrame(nodes, camera);
        SDL_Delay(10);
    }

    SDL_DestroyWindow(window);
    SDL_Quit();
}
