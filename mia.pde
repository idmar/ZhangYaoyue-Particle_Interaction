import com.hamoid.*;

import processing.sound.*;

import ddf.minim.*;
import java.nio.*;
// 多图片漂浮相关
class FloatingImg {
  PImage img;
  float x, y, vx, vy;
  float w, h;
}
ArrayList<FloatingImg> floatingImgs = new ArrayList<FloatingImg>();

Minim minim;
AudioPlayer player;

PShader glowShader;
ArrayList<Particle> particles = new ArrayList<Particle>();
ArrayList<PVector[]> connections = new ArrayList<PVector[]>();

PVector modelCenter;
float scaleFactor = 1.0;
float rotationY = 0;

int targetCount = 5000;  // 保持5000个粒子
int maxConnections = 1000;
float connectionDistance = 30;
float attractionForce = 0.008;

// 形状模式：0-模型形状，1-球形，2-立方体，3-圆柱形
int shapeMode = 0;
int totalShapeModes = 4;

PFont font;
// 调整调色板，以黄色、白色、蓝色为主
color[] basePalette = {
  #FFFFF0, #FFFFE0, #FFFFCC, #FFFFFF,  // 白色系
  #FFD700, #FFF8DC, #FFEC99, #FFFF00,  // 黄色系
  #E0FFFF, #B0E2FF, #87CEFA, #ADD8E6   // 蓝色系
};
float audioHue = 0;  // 音频控制色相
float baseBright = 1;
// 第一帧黄色控制
boolean firstFrame = true;
color initialYellow = #FFD700;

void setup() {
  // 缩小画布尺寸
  size(1100, 1400, P3D);
  smooth(4);
  colorMode(HSB, 360, 100, 100, 100);
  
  minim = new Minim(this);
  // 加载 data/ 目录下所有图片
  String[] imgFiles = {"博物馆之梦.jpg", "回溯经典.jpg", "回溯.png", "经典.png"};
  for (int i = 0; i < imgFiles.length; i++) {
    PImage img = loadImage("data/" + imgFiles[i]);
    if (img != null) {
      FloatingImg fi = new FloatingImg();
      fi.img = img;
      float maxW = width * 0.3;
      float maxH = height * 0.3;
      float scale = min(maxW / img.width, maxH / img.height, 1.0) * random(0.7, 1.0);
      fi.w = img.width * scale;
      fi.h = img.height * scale;
      fi.x = random(0, width - fi.w);
      fi.y = random(0, height - fi.h);
      fi.vx = random(-0.3, 0.3);
      fi.vy = random(-0.2, 0.2);
      floatingImgs.add(fi);
    }
  }
  try {
    player = minim.loadFile("科幻.mp3");
    player.loop();
    println("音频加载成功");
  } catch (Exception e) {
    println("音频加载失败: " + e.getMessage());
  }
  
  try {
    glowShader = loadShader("glow.frag");
    glowShader.set("resolution", float(width), float(height));
  } catch (Exception e) {
    println("Shader加载失败: " + e.getMessage());
  }
  
  // 初始创建粒子（模型形状）
  createParticlesByShape(shapeMode);
  
  font = loadFont("CenturySchoolbook-BoldItalic-48.vlw");
  if (font == null) {
    println("字体加载失败，使用默认字体");
  } else {
    textFont(font);
  }
  
  frameRate(144);
}

void draw() {
  background(0);
  
  // 先绘制文字，确保在粒子前面
  drawForegroundText();
  // 多图片均匀漂浮
  if (floatingImgs.size() > 0) {
    for (int i = 0; i < floatingImgs.size(); i++) {
      FloatingImg fi = floatingImgs.get(i);
      fi.x += fi.vx;
      fi.y += fi.vy;
      if (fi.x < 0 || fi.x > width - fi.w) fi.vx *= -1;
      if (fi.y < 0 || fi.y > height - fi.h) fi.vy *= -1;
      image(fi.img, fi.x, fi.y, fi.w, fi.h);
    }
  }
  
  // 再绘制粒子
  if (glowShader != null) shader(glowShader);
  pushMatrix();
  // 粒子居中显示，移除y轴偏移
  translate(width / 2, height / 2, 0);
  rotateZ(-PI/2);
  scale(scaleFactor * 1.2);
  
  // 完全由音频控制旋转
  if (player != null && player.isPlaying()) {
    float audioLevel = player.mix.level() * 8;  // 增强音频对旋转的影响
    rotationY += 0.001 + audioLevel * 0.003;
    // 音频控制色相变化
    audioHue = (audioHue + audioLevel * 3) % 360;
  } else {
    rotationY += 0.002;
    audioHue = (audioHue + 0.1) % 360;
  }
  rotateX(rotationY);
  
  updateParticles();
  drawConnections();
  drawParticles();
  
  if (glowShader != null) glowShader.set("resolution", float(width), float(height));
  popMatrix();
  if (glowShader != null) resetShader(); 
  
  // 绘制其他文字
  drawOtherText();
  
  // 第一帧结束后重置标志
  if (firstFrame) {
    firstFrame = false;
  }
}

// 绘制前景文字（在粒子前面）
void drawForegroundText() {
  fill(0, 0, 100); // 白色文字
  textSize(25);
  textAlign(LEFT, TOP);
  text("M+MUSEUM", 40, 60);  
  
  textSize(55);
  textAlign(CENTER, CENTER);
  text("THE DREAM OF MUSEUM", width/2, 350);  
}

// 绘制其他文字（在粒子后面或不遮挡主要内容的位置）
void drawOtherText() {
  fill(0, 0, 100); // 白色文字
  
  // 显示当前形状模式
  String shapeName;
  switch(shapeMode) {
    case 0: shapeName = "模型形状"; break;
    case 1: shapeName = "球形"; break;
    case 2: shapeName = "立方体"; break;
    case 3: shapeName = "圆柱形"; break;
    default: shapeName = "未知";
  }
  textSize(20);
  textAlign(LEFT, TOP);
  text("当前形状: " + shapeName, 40, 100);
  text("点击左侧区域切换形状", 50, 130);
  
  textSize(24);
  textAlign(LEFT, BOTTOM);
  text("FUTURE LIVING NIGHT (按T重置，上下键调整聚集度)", 40, height - 30);  

  textAlign(RIGHT, BOTTOM);
  text("@M-codo design", width - 30, height - 30);
  
  if (player != null) {
    textSize(16);
    textAlign(LEFT, BOTTOM);
    if (player.isPlaying()) {
      text("音频: 播放中 (空格暂停)", 40, height - 60);
    } else {
      text("音频: 已暂停 (空格播放)", 40, height - 60);
    }
  }
}

// 根据形状模式创建粒子
void createParticlesByShape(int mode) {
  particles.clear();
  connections.clear();
  
  float size = 180;
  
  switch(mode) {
    case 0: // 模型形状
      try {
        byte[] stlBytes = loadBytes("model.stl");
        float[] vertexData = parseBinarySTL(stlBytes);
        
        modelCenter = calculateCentroid(vertexData);
        createParticlesFromModel(vertexData);
        
        float maxDimension = getModelMaxDimension(vertexData);
        scaleFactor = min(width, height) * 0.85 / maxDimension;
        
        createConnections();
        println("模型形状加载完成，粒子数量: " + particles.size());
      } catch (Exception e) {
        println("模型加载失败: " + e.getMessage());
        // 模型加载失败时使用球形 fallback
        createSphericalParticles(size);
      }
      break;
      
    case 1: // 球形
      createSphericalParticles(size);
      scaleFactor = min(width, height) * 0.85 / (size * 2);
      createConnections();
      println("球形模式，粒子数量: " + particles.size());
      break;
      
    case 2: // 立方体
      createCubicalParticles(size);
      scaleFactor = min(width, height) * 0.85 / (size * 2);
      createConnections();
      println("立方体模式，粒子数量: " + particles.size());
      break;
      
    case 3: // 圆柱形
      createCylindricalParticles(size, size * 0.5);
      scaleFactor = min(width, height) * 0.85 / (size * 2);
      createConnections();
      println("圆柱形模式，粒子数量: " + particles.size());
      break;
  }
}

// 从模型创建粒子
void createParticlesFromModel(float[] vertices) {
  ArrayList<Face> faces = new ArrayList<Face>();
  for (int i = 0; i < vertices.length; i += 9) {
    PVector v1 = new PVector(vertices[i], vertices[i + 1], vertices[i + 2]);
    PVector v2 = new PVector(vertices[i + 3], vertices[i + 4], vertices[i + 5]);
    PVector v3 = new PVector(vertices[i + 6], vertices[i + 7], vertices[i + 8]);
    faces.add(new Face(v1, v2, v3));
  }
  for (int i = 0; i < targetCount; i++) {
    Face f = faces.get((int) random(faces.size()));
    PVector pt = randomPointInTriangle(f.v1, f.v2, f.v3);
    pt.sub(modelCenter);
    particles.add(new Particle(pt));
  }
}

// 创建球形粒子分布
void createSphericalParticles(float radius) {
  for (int i = 0; i < targetCount; i++) {
    float theta = random(TWO_PI);
    float phi = acos(random(-1, 1));
    float r = radius * pow(random(0.8), 1/3.0);
    
    float x = r * sin(phi) * cos(theta);
    float y = r * sin(phi) * sin(theta);
    float z = r * cos(phi);
    
    PVector pos = new PVector(x, y, z);
    particles.add(new Particle(pos));
  }
}

// 创建立方体粒子分布
void createCubicalParticles(float size) {
  for (int i = 0; i < targetCount; i++) {
    float x = random(-size * 0.8, size * 0.8);
    float y = random(-size * 0.8, size * 0.8);
    float z = random(-size * 0.8, size * 0.8);
    
    PVector pos = new PVector(x, y, z);
    particles.add(new Particle(pos));
  }
}

// 创建圆柱形粒子分布
void createCylindricalParticles(float radius, float height) {
  for (int i = 0; i < targetCount; i++) {
    float theta = random(TWO_PI);
    float r = radius * sqrt(random(0.64));
    float z = random(-height * 0.8, height * 0.8);
    
    float x = r * cos(theta);
    float y = r * sin(theta);
    
    PVector pos = new PVector(x, y, z);
    particles.add(new Particle(pos));
  }
}

float[] parseBinarySTL(byte[] bytes) {
  int faceCount = ByteBuffer.wrap(bytes, 80, 4).order(ByteOrder.LITTLE_ENDIAN).getInt();
  float[] vertices = new float[faceCount * 9];
  int offset = 84;
  for (int i = 0; i < faceCount; i++) {
    offset += 12;
    for (int j = 0; j < 9; j++) {
      vertices[i * 9 + j] = ByteBuffer.wrap(bytes, offset, 4).order(ByteOrder.LITTLE_ENDIAN).getFloat();
      offset += 4;
    }
    offset += 2;
  }
  return vertices;
}

PVector calculateCentroid(float[] vertices) {
  PVector sum = new PVector();
  int count = vertices.length / 3;
  for (int i = 0; i < vertices.length; i += 3) {
    sum.x += vertices[i];
    sum.y += vertices[i + 1];
    sum.z += vertices[i + 2];
  }
  return new PVector(sum.x / count, sum.y / count, sum.z / count);
}

PVector randomPointInTriangle(PVector a, PVector b, PVector c) {
  float u = random(1);
  float v = random(1);
  if (u + v > 1) {
    u = 1 - u;
    v = 1 - v;
  }
  return PVector.add(PVector.mult(a, 1 - u - v), PVector.add(PVector.mult(b, u), PVector.mult(c, v)));
}

float getModelMaxDimension(float[] vertices) {
  float minX = Float.MAX_VALUE, maxX = -Float.MAX_VALUE;
  float minY = Float.MAX_VALUE, maxY = -Float.MAX_VALUE;
  float minZ = Float.MAX_VALUE, maxZ = -Float.MAX_VALUE;
  for (int i = 0; i < vertices.length; i += 3) {
    minX = min(minX, vertices[i]); maxX = max(maxX, vertices[i]);
    minY = min(minY, vertices[i + 1]); maxY = max(maxY, vertices[i + 1]);
    minZ = min(minZ, vertices[i + 2]); maxZ = max(maxZ, vertices[i + 2]);
  }
  return max(maxX - minX, max(maxY - minY, maxZ - minZ));
}

void createConnections() {
  int attempts = 0;
  while (connections.size() < maxConnections && attempts < 200000) {
    int i = (int) random(particles.size());
    int j = (int) random(particles.size());
    if (i != j) {
      Particle p1 = particles.get(i);
      Particle p2 = particles.get(j);
      float dist = p1.position.dist(p2.position);
      if (dist > connectionDistance * 0.5 && dist < connectionDistance * 2) {
        connections.add(new PVector[]{p1.position, p2.position});
      }
    }
    attempts++;
  }
}

void drawParticles() {
  hint(DISABLE_DEPTH_TEST);
  beginShape(POINTS);
  for (Particle p : particles) {
    float hue;
    float audioLevel = 0;
    if (player != null && player.isPlaying()) {
      audioLevel = player.mix.level() * 5;
    }
    
    // 第一帧强制黄色
    if (firstFrame) {
      hue = hue(initialYellow);
    } else {
      // 由音频控制色相变化
      float base = (p.baseHue + audioHue) % 360;
      
      // 只保留黄、白、蓝三色范围
      if (base > 60 && base < 180) {
        hue = map(base, 60, 180, 50, 40);
      } else if (base > 240 && base < 350) {
        hue = map(base, 240, 350, 220, 190);
      } else {
        hue = base;
      }
    }
    
    // 提高饱和度和亮度，确保明亮效果
    float sat = 50 + 30 * sin(frameCount * 0.02 + p.position.x * 0.1 + audioLevel);
    // 显著提高亮度
    float bri = 98 + 2 * sin(frameCount * 0.01 + p.position.mag() * 0.1) + audioLevel * 12;
    
    // 确保亮度非常高
    stroke(hue, sat, constrain(bri, 95, 100), 95);
    // 粒子大小缩小，受音频影响变化
    strokeWeight(p.size + 0.2 + (player != null ? audioLevel * 0.6 : 0));
    vertex(p.position.x, p.position.y, p.position.z);
  }
  endShape();
  hint(ENABLE_DEPTH_TEST);
}

void drawConnections() {
  float alpha = 60; // 提高连接线透明度
  float audioLevel = 0;
  if (player != null && player.isPlaying()) {
    audioLevel = player.mix.level() * 5;
    alpha += audioLevel * 20;
  }
  
  float lineHue;
  // 第一帧连接线也用黄色系
  if (firstFrame) {
    lineHue = hue(initialYellow) + 20;
  } else {
    // 连接线由音频控制颜色
    lineHue = (audioHue + 30) % 240;
    if (lineHue > 60 && lineHue < 180) {
      lineHue = 45; // 黄色
    }
  }
  
  // 连接线保持高亮度
  stroke(lineHue, 40, 95, constrain(alpha, 40, 90));
  // 连接线粗细随音频变化
  strokeWeight(0.4 + audioLevel * 0.2);
  for (PVector[] pair : connections) {
    PVector p1 = pair[0];
    PVector p2 = pair[1];
    line(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z);
  }
}

void updateParticles() {
  float globalAudioInfluence = 0;
  if (player != null && player.isPlaying()) {
    globalAudioInfluence = player.mix.level() * 10;  // 增强音频影响
  }
  
  for (Particle p : particles) {
    float audioInfluence = globalAudioInfluence;
    p.speed = 1.2 + audioInfluence * 1.8;  // 音频对速度影响更大
    
    PVector toTarget = PVector.sub(p.target, p.position);
    toTarget.mult(attractionForce + audioInfluence * 0.006);
    
    if (p.state == 0) {
      PVector dir = PVector.sub(p.target, p.position);
      dir.mult(0.5 * p.speed);
      p.position.add(dir);
      if (dir.mag() < 2.0) p.state = 1;
    } else if (p.state == 1 && random(1) < 0.05 + audioInfluence * 0.03) {  // 音频更易触发漂移
      p.state = 2;
      p.drift = PVector.random3D().mult(random(0.3, 0.8) + audioInfluence * 0.3);
    } else if (p.state == 2) {
      // 漂移受音频影响更大
      p.drift.add(PVector.random3D().mult(0.03 + audioInfluence * 0.02));
      p.drift.limit(1.2 + audioInfluence * 1.0);
      p.position.add(p.drift);
      p.position.add(toTarget);
    }
  }
}

class Particle {
  PVector position;
  PVector target;
  float size;
  float speed;
  int state = 0;
  PVector drift;
  float baseHue;

  Particle(PVector tgt) {
    target = tgt.copy();
    position = target.copy().add(PVector.random3D().mult(30));
    size = random(0.3, 0.8);  // 粒子进一步缩小
    speed = random(1.5, 3.0);
    
    int colorValue = basePalette[(int)random(basePalette.length)];
    baseHue = hue(colorValue);
  }
}

class Face {
  PVector v1, v2, v3;
  Face(PVector v1, PVector v2, PVector v3) {
    this.v1 = v1;
    this.v2 = v2;
    this.v3 = v3;
  }
}

// 鼠标点击仅用于切换形状，不影响颜色
void mousePressed() {
  if (mouseX < width * 0.3) {
    shapeMode = (shapeMode + 1) % totalShapeModes;
    createParticlesByShape(shapeMode);
    println("切换到形状模式: " + shapeMode);
  }
}

// 完全移除鼠标移动控制
// void mouseMoved() { ... }

void keyPressed() {
  if (key == 's' || key == 'S') {
    saveFrame("thinker_####.png");
    println("保存截图完成");
  }
  
  if (key == ' ' && player != null) {
    if (player.isPlaying()) {
      player.pause();
      println("音频暂停");
    } else {
      player.loop();
      println("音频播放");
    }
  }
  
  if (key == 'r' && player != null) {
    player.rewind();
    player.play();
    println("音频重新播放");
  }
  
  if (key == 't' || key == 'T') {
    resetParticles();  // 按T键恢复初始形态
    println("粒子已重置为初始形态");
  }
  
  // 数字键1-4功能保留但不在界面显示
  if (key >= '1' && key <= '4') {
    shapeMode = int(key) - int('1');
    createParticlesByShape(shapeMode);
  }
  
  if (keyCode == UP) {
    attractionForce = min(attractionForce + 0.001, 0.03);
    println("吸引力增强: " + attractionForce);
  } else if (keyCode == DOWN) {
    attractionForce = max(attractionForce - 0.001, 0.002);
    println("吸引力减弱: " + attractionForce);
  }
}

// 重置粒子到初始形态
void resetParticles() {
  for (Particle p : particles) {
    p.state = 0;
    p.position = p.target.copy().add(PVector.random3D().mult(30));
    p.drift = new PVector();
  }
}

void stop() {
  if (player != null) {
    player.close();
  }
  if (minim != null) {
    minim.stop();
  }
  super.stop();
}
