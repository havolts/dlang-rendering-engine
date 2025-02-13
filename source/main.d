//main.d
import window, colour;
import std.stdio;
import core.thread;

extern (C)
{
    void pollEvents();
}
void main()
{
    Window window = new Window(1000, 1000, "My Window");
    window.start();
    Colour red = new Colour(255, 0, 0, 255); // Red color
    while (true)
    {
        pollEvents();
        for (int i = 0; i < 1000; i++)
        {
            for (int j = 0; j < 1000; j++)
            {
                Colour random = new Colour(i, j, i * j, 255 - (i));
                window.drawPixel(i, j, random);
                //writeln("Pixel drawn at (", i, ", ", j, ")");
            }
        }
        //writeln("Drawn");
        Thread.sleep(1000.msecs); // Add a small delay
    }
}
