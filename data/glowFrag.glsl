#version 150

out vec4 fragColor;

uniform float uTime;

void main() {
  float dist = distance(gl_PointCoord, vec2(0.5));
  float alpha = smoothstep(0.5, 0.2, dist);

  float glow = 0.3 + 0.7 * sin(uTime * 4.0 + gl_FragCoord.x * 0.05);

  fragColor = vec4(vec3(glow), alpha);
}
