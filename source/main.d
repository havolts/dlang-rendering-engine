//source/main.d
import macoswindowing.window;
import vector;

void main()
{
    shared Window win = new shared Window(1000, 750, "Test");
    win.start();

    while (true)
    {
        pollEvents();
    }
}

struct Vertex
{
    Vector2 position;
}
