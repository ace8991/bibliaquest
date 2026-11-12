shader_type spatial;
uniform sampler2D soil_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_pos;
varying vec3 weights;
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    weights = COLOR.rgb;
    // World-space UV projection with a matching tangent frame for the normal map.
    TANGENT = vec3(1.0,0.0,0.0);
    BINORMAL = vec3(0.0,0.0,1.0);
}
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void fragment() {
    vec2 uv=world_pos.xz*0.28;
    vec3 soil=texture(soil_color,uv).rgb;
    vec3 coarse=texture(soil_color,uv*0.31+vec2(0.32,0.17)).rgb;
    soil=mix(soil,coarse,0.27);
    float macro=noise(world_pos.xz*0.11);
    float path=clamp(weights.r,0.0,1.0);
    float river=clamp(weights.g,0.0,1.0);
    // Worn paths have muted fine detail; riverbed keeps a stonier surface.
    vec3 dust=mix(vec3(0.43,0.34,0.23),soil,0.20);
    vec3 rock=texture(stone_color,world_pos.xz*0.43).rgb;
    float gray=dot(rock,vec3(0.299,0.587,0.114));
    rock=mix(vec3(gray)*vec3(1.02,0.96,0.85),rock,0.16);
    vec3 ground=mix(soil,dust,path*0.9);
    ground=mix(ground,rock,river*0.75);
    ground*=mix(vec3(0.72,0.73,0.64),vec3(1.06,1.02,0.92),macro);
    ALBEDO=ground;
    NORMAL_MAP=texture(soil_normal,uv).rgb;
    NORMAL_MAP_DEPTH=mix(0.28,0.06,path);
    ROUGHNESS=0.94;
    SPECULAR=0.12;
}
