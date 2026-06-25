
struct float2
{
    float x;
    float y;
}

struct float3
{
    float x;
    float y;
    float z;

    float3 opUnary(string op)() const if (op == "-")
    {
        return float3(-x, -y, -z);
    }
}

struct float4
{
    float x;
    float y;
    float z;
    float w;
}

struct float4x4
{
    float[4][4] matrix;

    float4x4 opBinary(string op)(float4x4 other) const if (op == "+")
    {
        float4x4 result;
        for(int i = 0; i < 4; i++)
        {
            for(int j = 0; j < 4; j++)
            {
                result.matrix[i][j] = this.matrix[i][j] + other.matrix[i][j];
            }
        }
        return result;
    }

    float4x4 opBinary(string op)(float4x4 other) const if (op == "*")
    {
        float4x4 result;
        for(int i = 0; i < 4; i++)
        {
            float[4] row = this.matrix[i];
            for(int j = 0; j < 4; j++)
            {
                float[4] column = other.getColumn(j);
                float total = 0;
                for(int k = 0; k < 4; k++)
                {
                    total += (row[k]*column[k]);
                }
                result.matrix[i][j] = total;
            }
        }
        return result;
    }

    void rowToColumnMajor()
    {
        float[4][4] copy = matrix;
        matrix[0] = [copy[0][0], copy[1][0], copy[2][0], copy[3][0]];
        matrix[1] = [copy[0][1], copy[1][1], copy[2][1], copy[3][1]];
        matrix[2] = [copy[0][2], copy[1][2], copy[2][2], copy[3][2]];
        matrix[3] = [copy[0][3], copy[1][3], copy[2][3], copy[3][3]];
    }

    float[4] getColumn(int i)
    {
        float[4] column = [matrix[0][i], matrix[1][i], matrix[2][i], matrix[3][i]];
        return column;
    }
}

float dot(float3 a, float3 b)
{
    return (a.x * b.x) + (a.y * b.y) + (a.z * b.z);
}

/*
    0 , 1 , 2 , 3
    4 , 5 , 6 , 7
    8 , 9 , 10, 11
    12, 13, 14, 15
*/
