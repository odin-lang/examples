#version 330 core

////////////////////////////////////////////////////////////////////////////////
// STRUCTS
////////////////////////////////////////////////////////////////////////////////

struct Material {
    float shininess;
    vec3  color;
};

struct Directional_Light {
    vec3 dir;
    vec3 diffuse;
    vec3 specular;
};

struct Point_Light {
    vec3  pos;
    vec3  diffuse;
    vec3  specular;
    float constant;
    float linear;
    float quadratic;
};


////////////////////////////////////////////////////////////////////////////////
// INS / OUTS
////////////////////////////////////////////////////////////////////////////////

in vec3 vs_pos;
in vec3 vs_normal;
in vec2 vs_tex_coords;
out vec4 fs_color;


////////////////////////////////////////////////////////////////////////////////
// UNIFORMS
////////////////////////////////////////////////////////////////////////////////

uniform vec3 ambient_light;
uniform vec3 view_pos;
uniform Material material;
uniform Directional_Light dir_light;
uniform Point_Light point_light;


////////////////////////////////////////////////////////////////////////////////
// SHADER ENTRY-POINT
////////////////////////////////////////////////////////////////////////////////

void main() {
    vec3 view_dir = normalize(view_pos - vs_pos);
    vec3 diff_light = ambient_light;
    // Directional light
    vec3 dir_light_dir = normalize(-dir_light.dir);
    vec3 dir_light_reflect_dir = normalize(dir_light_dir + view_dir);
    diff_light += dir_light.diffuse * max(dot(normalize(vs_normal), dir_light_dir), 0.0);
    vec3 spec_light = dir_light.specular * pow(max(dot(view_dir, dir_light_reflect_dir), 0.0), material.shininess);
    // Point light
    vec3 point_light_dir = normalize(point_light.pos - vs_pos);
    vec3 point_light_reflect_dir = normalize(point_light_dir + view_dir);
    float point_light_distance = length(point_light.pos - vs_pos);
    float point_light_attenuation = 1.0 / (point_light.constant + point_light.linear * point_light_distance + point_light.quadratic * (point_light_distance * point_light_distance));
    diff_light += point_light_attenuation * (point_light.diffuse * max(dot(normalize(vs_normal), point_light_dir), 0.0));
    spec_light += point_light_attenuation * (point_light.specular * pow(max(dot(view_dir, point_light_reflect_dir), 0.0), material.shininess));
    // Output final color
    fs_color = vec4((diff_light * material.color + spec_light * vec3(1)), 1);
}
