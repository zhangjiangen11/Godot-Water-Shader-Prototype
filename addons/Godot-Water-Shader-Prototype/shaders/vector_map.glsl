#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D current_image;
layout(r32f, set = 1, binding = 0) uniform restrict writeonly image2D output_image;

layout(set = 3, binding = 0) uniform sampler2D flow_texture;

layout(push_constant, std430) uniform Params {
	float forward_offset;
	float forward_fadeoff;
	float flow_strength;
	float flow_randomize;
	float flow_random_speed;
	float blur_strength;
	float blur_offset;
	float curl_strength;
	float curl_offset;
	vec2 shift_vector;
	float shift_speed;
	float time;
} param;

// GET VECTOR MAP DELTA FOR HEIGHT MAP GENERATION
float get_delta(sampler2D tex, vec2 uv, float offset) {
	float pyt = 0.707107;
	
	vec2 m = texture(tex, uv).xy;
	
	vec2 p1 = texture(tex, fract( uv + vec2(0.0, -offset) ) ).xy;
	vec2 p2 = texture(tex, fract( uv + vec2(offset, 0.0) ) ).xy;
	vec2 p3 = texture(tex, fract( uv + vec2(0.0, offset) ) ).xy;
	vec2 p4 = texture(tex, fract( uv + vec2(-offset, 0.0) ) ).xy;
	vec2 p5 = texture(tex, fract( uv + vec2(offset, -offset) * pyt ) ).xy;
	vec2 p6 = texture(tex, fract( uv + vec2(offset, offset) * pyt ) ).xy;
	vec2 p7 = texture(tex, fract( uv + vec2(-offset, offset) * pyt ) ).xy;
	vec2 p8 = texture(tex, fract( uv + vec2(-offset, -offset) * pyt ) ).xy;
	
	return ( length(m - p1) + length(m - p2) + length(m - p3) + length(m - p4) + length(m - p5) + length(m - p6) + length(m - p7) + length(m - p8) ) * 0.125;
}

vec2 get_average(sampler2D tex, vec2 uv, float offset) {
	float pyt = 0.707107;
	
	vec2 p1 = texture(tex, fract( uv + vec2(0.0, -offset) ) ).xy;
	vec2 p2 = texture(tex, fract( uv + vec2(offset, 0.0) ) ).xy;
	vec2 p3 = texture(tex, fract( uv + vec2(0.0, offset) ) ).xy;
	vec2 p4 = texture(tex, fract( uv + vec2(-offset, 0.0) ) ).xy;
	vec2 p5 = texture(tex, fract( uv + vec2(-offset, -offset) * pyt ) ).xy;
	vec2 p6 = texture(tex, fract( uv + vec2(offset, -offset) * pyt ) ).xy;
	vec2 p7 = texture(tex, fract( uv + vec2(offset, offset) * pyt ) ).xy;
	vec2 p8 = texture(tex, fract( uv + vec2(-offset, offset) * pyt ) ).xy;
	
	return (p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8) / 8.0;
}

vec2 get_forward(sampler2D tex, vec2 uv, float offset, float fadeout) {
	float forward_fadeout = 0.414 - fadeout; //0.414 default
	float pyt = 0.707107;
	
	vec2 p1 = texture(tex, fract( uv + vec2(0.0, -offset) ) ).xy - 0.5;
	vec2 p2 = texture(tex, fract( uv + vec2(offset, -offset) * pyt ) ).xy - 0.5;
	vec2 p3 = texture(tex, fract( uv + vec2(offset, 0.0) ) ).xy - 0.5;
	vec2 p4 = texture(tex, fract( uv + vec2(offset, offset) * pyt) ).xy - 0.5;
	vec2 p5 = texture(tex, fract( uv + vec2(0.0, offset) ) ).xy - 0.5;
	vec2 p6 = texture(tex, fract( uv + vec2(-offset, offset) * pyt) ).xy - 0.5;
	vec2 p7 = texture(tex, fract( uv + vec2(-offset, 0.0) ) ).xy - 0.5;
	vec2 p8 = texture(tex, fract( uv + vec2(-offset, -offset) * pyt) ).xy - 0.5;
	
	vec2 middle = vec2(0.0, 0.0);
	
	middle.y += clamp(dot(p1, vec2(0.0, 1.0)) * forward_fadeout, 0.0, 1.0);
	middle.y += clamp(dot(p2, vec2(-pyt, pyt) ) * forward_fadeout, 0.0, 1.0);
	middle.y += clamp(dot(p8, vec2(pyt, pyt) ) * forward_fadeout, 0.0, 1.0);
	
	middle.x -= clamp(dot(p2, vec2(-pyt, pyt) ) * forward_fadeout, 0.0, 1.0);
	middle.x -= clamp(dot(p3, vec2(-1.0, 0.0)) * forward_fadeout, 0.0, 1.0);
	middle.x -= clamp(dot(p4, vec2(-pyt, -pyt) ) * forward_fadeout, 0.0, 1.0);
	
	middle.y -= clamp(dot(p4, vec2(-pyt, -pyt) ) * forward_fadeout, 0.0, 1.0);
	middle.y -= clamp(dot(p5, vec2(0.0, -1.0)) * forward_fadeout, 0.0, 1.0);
	middle.y -= clamp(dot(p6, vec2(pyt, -pyt) ) * forward_fadeout, 0.0, 1.0);
	
	middle.x += clamp(dot(p6, vec2(pyt, -pyt) ) * forward_fadeout, 0.0, 1.0);
	middle.x += clamp(dot(p7, vec2(1.0, 0.0)) * forward_fadeout, 0.0, 1.0);
	middle.x += clamp(dot(p8, vec2(pyt, pyt) ) * forward_fadeout, 0.0, 1.0);
	
	return middle;
}

vec2 get_curl(sampler2D tex, vec2 uv, float offset) {
	vec2 middle = vec2(0.0, 0.0);
	float pyt = 0.707107;
	
	vec2 p1 = texture(tex, fract( uv + vec2(0.0, -offset) ) ).xy - 0.5;
	vec2 p2 = texture(tex, fract( uv + vec2(0.0, -offset * 2.0) ) ).xy - 0.5;
	vec2 p3 = texture(tex, fract( uv + vec2(offset, 0.0) ) ).xy - 0.5;
	vec2 p4 = texture(tex, fract( uv + vec2(offset * 2.0, 0.0) ) ).xy - 0.5;
	vec2 p5 = texture(tex, fract( uv + vec2(0.0, offset) ) ).xy - 0.5;
	vec2 p6 = texture(tex, fract( uv + vec2(0.0, offset * 2.0) ) ).xy - 0.5;
	vec2 p7 = texture(tex, fract( uv + vec2(-offset, 0.0) ) ).xy - 0.5;
	vec2 p8 = texture(tex, fract( uv + vec2(-offset * 2.0, 0.0) ) ).xy - 0.5;
	
	vec2 p9 = texture(tex, fract( uv + vec2(offset, -offset) * pyt ) ).xy - 0.5;
	vec2 p10 = texture(tex, fract( uv + vec2(offset * 2.0, -offset * 2.0) * pyt ) ).xy - 0.5;
	vec2 p11 = texture(tex, fract( uv + vec2(offset, offset) * pyt ) ).xy - 0.5;
	vec2 p12 = texture(tex, fract( uv + vec2(offset * 2.0, offset * 2.0) * pyt ) ).xy - 0.5;
	vec2 p13 = texture(tex, fract( uv + vec2(-offset, offset) * pyt ) ).xy - 0.5;
	vec2 p14 = texture(tex, fract( uv + vec2(-offset * 2.0, offset * 2.0) * pyt ) ).xy - 0.5;
	vec2 p15 = texture(tex, fract( uv + vec2(-offset, -offset) * pyt ) ).xy - 0.5;
	vec2 p16 = texture(tex, fract( uv + vec2(-offset * 2.0, -offset * 2.0) * pyt ) ).xy - 0.5;
	
	middle += ( (p1 - p2) + (p3 - p4) + (p5 - p6) + (p7 - p8) + (p9 - p10) + (p11 - p12) + (p13 - p14) + (p15 - p16) ) * 0.005;
	
	return middle;
}

void main() {
	vec2 uv = gl_GlobalInvocationID.xy / vec2(imageSize(output_image) - 1);
	vec2 uv_shifted = fract( uv + vec2(sin(param.time * param.shift_speed) * param.shift_vector.x * 0.01, cos(param.time * param.shift_speed * 0.97231) * param.shift_vector.y * 0.01) );
	
	// creation of vector map based on the buffer
	vec2 flow_pixel = vec2(0.5, 0.5);
	flow_pixel += get_forward(current_image, uv_shifted, param.forward_offset / 1024.0, param.forward_fadeoff);
	flow_pixel += get_curl(current_image, uv_shifted, param.curl_offset / 1024.0) * param.curl_strength;
	flow_pixel = mix(flow_pixel, get_average(current_image, uv_shifted, param.blur_offset / 1024.0), param.blur_strength);
	
	// texture input flow direction (RED, GREEN), flow strength (BLUE)
	vec3 flow_source = texture(flow_texture, uv).xyz;
	float flow_source_overlay = texture(flow_texture, fract( uv + vec2(param.time * 0.0121, param.time * 0.0372))).z;
	
	// random input controlled by shader params	
	vec2 flow_random = vec2( sin(uv.x * 6.25 + param.time * param.flow_random_speed) * 0.5 + 0.5, cos(uv.y * 6.25 + param.time * param.flow_random_speed) * 0.5 + 0.5 );
	// flow strength modifier controlled by shader params
	flow_source.z *= flow_source_overlay * clamp(param.flow_strength, 0.0, 1.0);
	// random input applied to vector map with texture input
	flow_source.xy = mix(flow_source.xy, flow_random, param.flow_randomize);
	
	float height = ( get_delta(current_image, uv, 0.0009765625) + get_delta(current_image, uv, 0.001953125) + get_delta(current_image, uv, 0.00390625) + get_delta(current_image, uv, 0.0078125) + get_delta(current_image, uv, 0.015625) + get_delta(current_image, uv, 0.03125) + get_delta(current_image, uv, 0.0625) );
	
	imageStore(output_image, ivec2(gl_GlobalInvocationID.xy), vec4(mix(flow_pixel, flow_source.xy, flow_source.z), height , 1.0));
}
