struct SpriteData
{
    uint position_and_color;
};

// set = 0, binding = 1  →  register(t1)
StructuredBuffer<SpriteData> sprites : register(t1, space0);

struct VSOutput
{
    float4 position     : SV_Position;
    float2 uv           : TEXCOORD0;
    uint   sprite_index : COLOR0;
};

// --------- Constants ---------
static const float2 vertex_pos[4] = {
    float2(0.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 0.0),
    float2(1.0, 1.0)
};

// ---- Convert from pixel coordinates to NDC (-1..1) ----
static const float2 sprite_size = float2(  52.0,  74.0);
static const float2 screen_size = float2(1280.0, 720.0);

// ---- Quad Size in NDC ----
static const float2 sprite_size_ndc = sprite_size / screen_size;

static const float num_cols = 1.0;
static const float num_rows = 5.0;

// ---- Precomputed SpriteSheet UVs ----
// Uncomment to use the spritesheet, with multi colored bunnies.
// struct SpriteUV
// {
//     float2 uv_min;
//     float2 uv_max;
// };

// static const SpriteUV uvs[5] = {
//     { float2(  0.0, 0.01  ), float2(  0.9, 0.22 ) },
//     { float2(  0.0, 0.236 ), float2( 0.96, 0.4  ) },
//     { float2(  0.0, 0.42  ), float2(  1.0, 0.6  ) },
//     { float2(  0.0, 0.62  ), float2(  1.0, 0.8  ) },
//     { float2(  0.0, 0.8   ), float2(  1.0, 1.0  ) },
// };

VSOutput main(uint vertexID : SV_VertexID, uint instanceID : SV_InstanceID)
{
    VSOutput output;

    // ---- Indexing ----
    uint instance_index = instanceID;
    uint vertex_index = vertexID % 4;

    // ---- Load packed sprite data once ----
    uint packed = sprites[instance_index].position_and_color;

    // ---- Decode packed fields ----
    // [x, x, x, x, x, x, x, x, x, x, x, y, y, y, y, y, y, y, y, y, y, s, s, s, s, 0, 0, 0, 0, 0, 0, 0] (11x, 10y, 4s) 7 bit padding
    uint px = (packed >> 21) & 0x7FFu;  // 11 bits
    uint py = (packed >> 11) & 0x3FFu;  // 10 bits
    // uint si = (packed >>  7) & 0xFu  ;  // 4 bits

    // ---- Position in NDC ----
    float2 position = float2(px, py);
    float2 ndc_pos = (position / screen_size) * 2.0f - 1.0f;

    float2 vertex_coord = vertex_pos[vertex_index];
    float2 offset = (vertex_coord - 0.5f) * sprite_size_ndc;

    float2 world_pos = ndc_pos + offset;

    output.position = float4(world_pos.x, -world_pos.y, 0.0, 1.0);

    // For Sprite Sheet
    // Uncomment to see multicolored bunnies, instead of a single colored.
    // SpriteUV uv = uvs[si];
    // output.uv = lerp(uv.uv_min, uv.uv_max, vertex_coord);

    // Single Sprite
    output.uv = vertex_coord;

    return output;
}