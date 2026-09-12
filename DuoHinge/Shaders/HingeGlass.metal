#include <metal_stdlib>

using namespace metal;
constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear);
half4 hingeGlass(float2 position, texture2d<half> layer, float4 bounds, float progress, float blurStrength, float darknessStrength, float3 viewpoint) {
    float2 size = bounds.zw;
    float2 p = position - bounds.xy;
    float angle = clamp(progress, 0.0f, 1.0f) * M_PI_F * 0.5f;
    // An exact passthrough at the reference angle avoids a color/geometry jump.
    if (angle < 1e-5f) return half4(layer.sample(linearSampler, (position) / bounds.zw).rgb, 1.0h);
    // Delayed, wider curtain: never extinguish the desktop. At full closure
    // the top retains 40% transmission and the bottom retains even more.
    float curtainProgress = smoothstep(0.20f, 1.0f, clamp(progress, 0.0f, 1.0f));
    float feather = 0.22f;
    float edge = mix(-feather, 0.90f, curtainProgress);
    float curtain = 1.0f - smoothstep(edge - feather, edge + feather, p.y / size.y);
    float visibility = 1.0f - min(0.60f * darknessStrength, 0.80f) * curtain;
    // Ease optical scattering smoothly near the reference pose.
    float opticalStrength = smoothstep(0.0f, 1.5f / 90.0f, progress);
    float distance = size.y - p.y;
    // World coordinates: the desktop remains on z=0 at the 90-degree position.
    // Only the physical glass rotates about (y=height, z=0). For each glass
    // pixel, continue the stationary eye's ray to the fixed desktop plane.
    // Do not compress or rotate that desktop a second time in screen space.
    float eyeDistance = size.y * max(viewpoint.z, 1.1f);
    float sine = sin(angle);
    float cosine = cos(angle);
    float3 eye = float3(size.x * viewpoint.x, size.y * viewpoint.y, eyeDistance);
    float3 glass = float3(p.x, size.y - distance * cosine, distance * sine);
    float depth = eye.z - glass.z;
    if (depth <= 1e-5f) return half4(0, 0, 0, 1);
    float rayScale = eye.z / depth;
    float2 hit = eye.xy + (glass.xy - eye.xy) * rayScale;
    float separation = distance * sine;
    // A narrow contact band remains optically clear; scattering increases smoothly
    // with glass separation. Cap the footprint to avoid sparse, ghosted large kernels.
    float contact = smoothstep(size.y * 0.035f, size.y * 0.20f, distance);
    float scatter = separation * 0.070f * contact * opticalStrength * blurStrength;
    // Smooth saturation retains a changing slope instead of abruptly hitting a cap.
    float radius = scatter / sqrt(1.0f + (scatter / 36.0f) * (scatter / 36.0f));
    // Projection is sampled once. The following two passes supply the blur.
    bool inside = all(hit >= 0.0f) && all(hit < size);
    half3 color = inside ? layer.sample(linearSampler, (bounds.xy + hit) / bounds.zw).rgb : half3(0);
    float transmission = 1.0f - min(radius * 0.0004f, 0.015f);
    return half4(color * half(transmission * visibility), 1.0h);
}

// Separable Gaussian in display coordinates. Two dense 1D passes avoid sparse
// disk replicas of fine text. Adjacent weights share a bilinear texture read.
half4 hingeGaussian(float2 position, texture2d<half> layer,
                                     float4 bounds, float progress, float2 direction, float blurStrength) {
    float2 size = bounds.zw;
    float2 p = position - bounds.xy;
    float distance = size.y - p.y;
    float contact = smoothstep(size.y * 0.035f, size.y * 0.20f, distance);
    float optical = smoothstep(0.0f, 1.5f / 90.0f, progress);
    float scatter = distance * sin(clamp(progress, 0.0f, 1.0f) * M_PI_F * 0.5f)
                  * 0.070f * contact * optical * blurStrength;
    float radius = scatter / sqrt(1.0f + (scatter / 36.0f) * (scatter / 36.0f));
    if (radius < 0.35f) return half4(layer.sample(linearSampler, (position) / bounds.zw).rgb, 1);
    float sigma = max(radius / 2.44948974f, 0.15f);
    float inverseVariance = 0.5f / (sigma * sigma);
    float3 sum = float3(layer.sample(linearSampler, (position) / bounds.zw).rgb);
    float total = 1.0f;
    for (int i = 1; i <= 35; i += 2) {
        float a = float(i), b = a + 1.0f;
        float wa = exp(-a * a * inverseVariance);
        float wb = exp(-b * b * inverseVariance);
        float weight = wa + wb;
        if (weight < 1e-7f) continue;
        float offset = (a * wa + b * wb) / weight;
        for (int side = -1; side <= 1; side += 2) {
            // Extend the edge rather than introducing a dark sampling border.
            float2 q = clamp(p + direction * (float(side) * offset),
                             float2(0.0f), max(size - 0.5f, float2(0.0f)));
            sum += float3(layer.sample(linearSampler, (bounds.xy + q) / bounds.zw).rgb) * weight;
        }
        total += 2.0f * weight;
    }
    return half4(half3(sum / total), 1);
}

// NameDrop-inspired dispersion, not a reproduction of Apple's implementation.
// Applied after blur in display coordinates; the fixed-plane projection is unchanged.
half4 hingeChromatic(float2 position, texture2d<half> layer,
                                      float4 bounds, float progress, float strength) {
    half4 center = layer.sample(linearSampler, (position) / bounds.zw);
    float closing = clamp(progress, 0.0f, 1.0f);
    if (strength <= 0.0f || closing <= 0.0f) return center;

    float2 size = max(bounds.zw, float2(1.0f));
    float2 p = position - bounds.xy;
    float heightFromHinge = clamp((size.y - p.y) / size.y, 0.0f, 1.0f);
    float contact = smoothstep(0.035f, 0.20f, heightFromHinge);
    float onset = smoothstep(0.0f, 2.5f / 90.0f, closing);
    float amount = min(size.y * 0.009f, 10.0f) * clamp(strength, 0.0f, 1.0f)
                 * sin(closing * M_PI_F * 0.5f) * onset * contact
                 * pow(heightFromHinge, 1.35f);
    if (amount < 0.001f) return center;

    // Radial dispersion around the bottom-center hinge. The narrow contact band
    // stays neutral; separation grows toward the top and outer edges.
    float2 radial = float2((p.x / size.x - 0.5f) * 0.65f, -heightFromHinge);
    float2 offset = radial / max(length(radial), 0.0001f) * amount;
    float2 upper = max(size - 0.5f, float2(0.0f));
    float2 redPosition = bounds.xy + clamp(p + offset, float2(0.0f), upper);
    float2 bluePosition = bounds.xy + clamp(p - offset, float2(0.0f), upper);
    // Extend the edge instead of introducing colored transparency fringes.
    return half4(layer.sample(linearSampler, (redPosition) / bounds.zw).r, center.g, layer.sample(linearSampler, (bluePosition) / bounds.zw).b, center.a);
}

struct HingeUniforms {
    float4 geometry; // point width, point height, progress, blur
    float4 optics;   // darkness, chromatic strength, unused, unused
    float4 eye;
};
struct HingeVertex { float4 position [[position]]; float2 uv; };
vertex HingeVertex hingeVertex(uint index [[vertex_id]]) {
    float2 uv = float2((index << 1) & 2, index & 2);
    return {float4(uv.x * 2 - 1, 1 - uv.y * 2, 0, 1), uv};
}
fragment half4 hingeProject(HingeVertex in [[stage_in]], texture2d<half> source [[texture(0)]],
                           constant HingeUniforms &u [[buffer(0)]]) {
    return hingeGlass(in.uv * u.geometry.xy, source, float4(0, 0, u.geometry.xy),
                      u.geometry.z, u.geometry.w, u.optics.x, u.eye.xyz);
}
fragment half4 hingeBlurX(HingeVertex in [[stage_in]], texture2d<half> source [[texture(0)]],
                         constant HingeUniforms &u [[buffer(0)]]) {
    return hingeGaussian(in.uv * u.geometry.xy, source, float4(0, 0, u.geometry.xy),
                         u.geometry.z, float2(1, 0), u.geometry.w);
}
fragment half4 hingeBlurY(HingeVertex in [[stage_in]], texture2d<half> source [[texture(0)]],
                         constant HingeUniforms &u [[buffer(0)]]) {
    return hingeGaussian(in.uv * u.geometry.xy, source, float4(0, 0, u.geometry.xy),
                         u.geometry.z, float2(0, 1), u.geometry.w);
}
fragment half4 hingeDispersion(HingeVertex in [[stage_in]], texture2d<half> source [[texture(0)]],
                              constant HingeUniforms &u [[buffer(0)]]) {
    return hingeChromatic(in.uv * u.geometry.xy, source, float4(0, 0, u.geometry.xy),
                          u.geometry.z, u.optics.y);
}
