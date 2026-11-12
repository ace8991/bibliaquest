shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth_color : source_color = vec4(0.5,0.44,0.33,1.0);
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
    float u = local_position.x + local_position.z * 0.61;
    float v = local_position.y + local_position.z * 0.79;
    float weave = sin(u * 480.0) * sin(v * 480.0);
    // Fade subpixel threads to avoid distant moire; preserve broad weathering.
    float detail = 1.0 - smoothstep(0.002, 0.012, length(fwidth(local_position)));
    float weather = sin(u * 9.0 + sin(v * 7.0)) * sin(v * 13.0) * 0.045;
    float dust = 1.0 - smoothstep(0.0, 0.65, local_position.y);
    float seam = 1.0 - smoothstep(0.008, 0.018, abs(fract(local_position.z * 0.7 + 0.5) - 0.5));
    ALBEDO = cloth_color.rgb * (0.92 + weave * 0.06 * detail + weather - dust * 0.23 - seam * 0.065);
    ROUGHNESS = 0.96;
    SPECULAR = 0.16;
}
