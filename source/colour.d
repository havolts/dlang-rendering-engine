//colour.d
class Colour
{
    float r, g, b, a;

    this(float inR, float inG, float inB, float inA)
    {
        r = inR / 255;
        g = inG / 255;
        b = inB / 255;
        a = inA / 255;
    }
}
