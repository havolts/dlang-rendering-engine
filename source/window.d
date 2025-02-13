//window.d
import std.stdio, std.conv, std.string;
import colour;

extern (C)
{
    void initializeApplication();
    void* createWindow(float width, float height, immutable(char)* title);
    void setupWindow(void* window);
    void activateApplication();
    void pollEvents();
    void DrawPixelC(void* window, int x, int y, float r, float g, float b, float a);
}

class Window
{
    void* window;
    int width, height;
    string title;
    this(int inWidth, int inHeight, string inTitle)
    {
        width = inWidth;
        height = inHeight;
        title = inTitle;
        initializeApplication();
    }

    void start()
    {
        title = format(title);
        window = createWindow(width, height, title.toStringz());
        setupWindow(window);
        activateApplication();
    }

    void drawPixel(int x, int y, Colour c)
    {
        // Ensure x and y are within bounds
        if (x >= 0 && x < width && y >= 0 && y < height)
        {
            DrawPixelC(window, x, y, c.r, c.g, c.b, c.a);
        }
        else
        {
            writeln("[WARNING] Pixel coordinates out of bounds: (", x, ", ", y, ")");
        }
    }
}
