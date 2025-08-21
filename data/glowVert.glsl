#version 150

uniform mat4 transform;
uniform mat4 modelview;
uniform mat4 projection;
uniform float uTime;

in vec4 position;

void main() {
  gl_Position = projection * modelview * position;
  gl_PointSize = 6.0;
}
