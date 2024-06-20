struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) texCoord: vec2<f32>,
    @location(1) @interpolate(flat) color: u32,
};

@vertex 
fn vs_main(
@location(0) pos: vec2<f32>,
    @location(1) texCoord: vec2<f32>,
    @location(2) color: u32
) -> VertexOutput {
    var output: VertexOutput;
    output.position = transform * vec4<f32>(pos, 0, 1);
    output.texCoord = texCoord;
    output.color    = color;
    return output;
}

@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var text: texture_2d<f32>;
@group(0) @binding(2) var<uniform> transform: mat4x4<f32>;

@fragment 
fn fs_main(@location(0) texCoord: vec2<f32>, @location(1) @interpolate(flat) color: u32) -> @location(0) vec4<f32> {
    // NOTE: this samples rgba, but the texture just contains the alpha channel,
    // so in practice `r` is the alpha, and the rest is junk.
    let texColor = textureSample(text, samp, texCoord);
    let a = texColor.r * f32((color >> 24) & 0xffu) / 255;
    let b = f32((color >> 16) & 0xffu) / 255;
    let g = f32((color >> 8) & 0xffu) / 255;
    let r = f32(color & 0xffu) / 255;
    return vec4<f32>(r, g, b, a);
}
