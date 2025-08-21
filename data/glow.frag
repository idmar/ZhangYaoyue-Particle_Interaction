#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform sampler2D texture;
uniform vec2 resolution;

void main() {
  vec2 uv = gl_FragCoord.xy / resolution;
  
  vec4 base = texture2D(texture, uv);
  vec3 glowColor = vec3(1.0, 0.84, 0.0);

  // 模拟光晕 - 周围8方向模糊采样
  float glow = 0.0;
  float total = 0.0;
  float radius = 1.0;

  for (float x = -radius; x <= radius; x++) {
    for (float y = -radius; y <= radius; y++) {
      vec2 offset = vec2(x, y) / resolution * 2.0;
      float weight = 1.0 - length(offset) / radius;
      glow += texture2D(texture, uv + offset).a * weight;
      total += weight;
    }
  }

  glow /= total;

  // 混合基础颜色与 glow
  vec3 result = base.rgb + glow * glowColor * 0.8;

  gl_FragColor = vec4(result, 1.0);
}
