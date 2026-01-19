@group(0) @binding(0) var<uniform> grid : vec2f;
@group(0) @binding(1) var<storage> cellStateIn : array<u32>;
@group(0) @binding(2) var<storage, read_write> cellStateOut : array<u32>;

fn cellIndex(cell : vec2u) -> u32 {
    return (cell.y % u32(grid.y)) * u32(grid.x) + (cell.x % u32(grid.x));
}

fn cellActive(x : u32, y : u32) -> u32 {
    return cellStateIn[cellIndex(vec2(x, y))];
}

@compute @workgroup_size(8, 8)
fn computeMain(@builtin(global_invocation_id) cell : vec3u) {
    let activeNeighbors =
            cellActive(cell.x + 1u, cell.y + 1u) +
            cellActive(cell.x + 1u, cell.y + 0u) +
            cellActive(cell.x + 1u, cell.y - 1u) +
            cellActive(cell.x + 0u, cell.y - 1u) +
            cellActive(cell.x - 1u, cell.y - 1u) +
            cellActive(cell.x - 1u, cell.y + 0u) +
            cellActive(cell.x - 1u, cell.y + 1u) +
            cellActive(cell.x + 0u, cell.y + 1u);

    let i = cellIndex(cell.xy);

    switch activeNeighbors {
          case 2u: { cellStateOut[i] = cellStateIn[i]; }
          case 3u: { cellStateOut[i] = 1u; }
          default: { cellStateOut[i] = 0u; }
    }
}
