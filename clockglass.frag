#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 srcSize;
    vec2 srcOffset;
    float mode;
    float intensity;
    float refract;
    float bevel;
    vec4 tint;
    vec2 lightDir;
};

layout(binding = 1) uniform sampler2D src;
layout(binding = 2) uniform sampler2D mask;
layout(binding = 3) uniform sampler2D hmap;

float H(vec2 uv) { return texture(hmap, uv).a; }
vec3 backdrop(vec2 p, float lod) { return textureLod(src, clamp(p / srcSize, vec2(0.001), vec2(0.999)), lod).rgb; }

void main()
{
    vec2 uv = qt_TexCoord0;
    float coverage = texture(mask, uv).a;
    if (coverage <= 0.002) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 p = uv * itemSize + srcOffset;
    float luminance;
    vec3 solidBackground = backdrop(p, 2.0);
    luminance = dot(solidBackground, vec3(0.299, 0.587, 0.114));
    solidBackground = mix(vec3(luminance), solidBackground, 1.35);
    vec3 solid = mix(solidBackground, tint.rgb, clamp(intensity, 0.0, 1.0)) + 0.04;

    vec2 d = 2.0 / itemSize;
    vec2 gradient = vec2(H(uv + vec2(d.x, 0.0)) - H(uv - vec2(d.x, 0.0)),
                         H(uv + vec2(0.0, d.y)) - H(uv - vec2(0.0, d.y))) * 0.5;
    float slope = length(gradient) * bevel;
    float curve = clamp(slope, 0.0, 1.0);
    vec2 normal = slope > 1e-6 ? -gradient / length(gradient) : vec2(0.0);
    float bend = curve * curve * (3.0 - 2.0 * curve);
    vec2 shift = normal * refract * (0.35 * curve + 0.65 * bend);
    float lod = 0.65 + 0.95 * intensity;
    vec3 glassBackground;
    glassBackground.r = backdrop(p - shift * 1.04, lod).r;
    glassBackground.g = backdrop(p - shift, lod).g;
    glassBackground.b = backdrop(p - shift * 0.96, lod).b;
    luminance = dot(glassBackground, vec3(0.299, 0.587, 0.114));
    glassBackground = mix(vec3(luminance), glassBackground, 1.08);
    vec3 glass = glassBackground * 1.04 + 0.04;
    glass = mix(glass, mix(vec3(1.0), tint.rgb, 0.85), 0.28 + 0.36 * intensity);
    glass = mix(glass, glass * tint.rgb, 0.35 * (1.0 - tint.r * tint.g * tint.b));
    float facing = dot(normal, normalize(lightDir));
    float shade = facing * smoothstep(0.0, 0.55, curve);
    glass *= 1.0 + 0.22 * shade;
    glass += 0.10 * max(shade, 0.0) * (1.0 - 0.5 * intensity);
    vec3 color = mix(solid, glass, clamp(mode, 0.0, 1.0));
    fragColor = vec4(clamp(color, 0.0, 1.0) * coverage, coverage) * qt_Opacity;
}