module camera;
import macoswindowing.window;
import metalrendering;
import mesh;
import std.stdio;
import std.math;
import types;
import texture;


class Camera
{
    public float3 position = float3(0f,0f,1f);
    public float3 rotation = float3(0f,0f,0f);

    public float4x4 viewMatrix;

    float3 R;
    float3 U;
    float3 F;

    this()
    {
        Update();
    }

    void Update()
    {
        float3x3 rotationX = float3x3([[1f,0,0],
                            [0,cos(rotation.x),-sin(rotation.x)],
                            [0,sin(rotation.x),cos(rotation.x)]]);
        float3x3 rotationY = float3x3([[cos(rotation.y),0,sin(rotation.y)],
                            [0,1f,0],
                            [-sin(rotation.y),0,cos(rotation.y)]]);
        float3x3 rotationZ = float3x3([[cos(rotation.z),-sin(rotation.z),0],
                            [sin(rotation.z),cos(rotation.z),0],
                            [0,0,1f]]);
        float3x3 rotationMatrix = rotationX * rotationY * rotationZ;

        R = rotationMatrix * float3(1f,0,0);
        U = rotationMatrix * float3(0,1f,0);
        F = rotationMatrix * float3(0,0,-1f);

        viewMatrix = float4x4([[R.x, R.y, R.z, dot(-R, position)],
                                [U.x, U.y, U.z, dot(-U, position)],
                                [-F.x, -F.y, -F.z, dot(F, position)],
                                [0f , 0f , 0f , 1f]]);

        viewMatrix.rowToColumnMajor();
    }
}
