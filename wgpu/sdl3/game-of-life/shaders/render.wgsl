struct VertexInput {
    @location(0) pos : vec2f,
    @builtin(instance_index) instance : u32,
};

struct VertexOutput {
    @builtin(position) pos : vec4f,
    @location(0) cell : vec2f,
};

@group(0) @binding(0) var<uniform> grid : vec2f;
@group(0) @binding(1) var<storage> cellState : array<u32>;

@vertex
fn vertexMain(input : VertexInput) -> VertexOutput {
    let i = f32(input.instance);
    let cell = vec2f(i % grid.x, floor(i / grid.x));
    let state = f32(cellState[input.instance]);

    let cellOffset = cell / grid * 2.0;
    let gridPos = (input.pos * state + 1.0) / grid - 1.0 + cellOffset;

    var out : VertexOutput;
    out.pos = vec4f(gridPos, 0.0, 1.0);
    out.cell = cell;
    return out;
}

@fragment
fn fragmentMain(input : VertexOutput) -> @location(0) vec4f {
    let c = input.cell / grid;
    return vec4f(c, 1.0 - c.x, 1.0);
}
