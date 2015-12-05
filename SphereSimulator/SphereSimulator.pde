/*

  Sphere Simulator and Lighter
  
  1. Simulator: draws sphere on the monitor
  2. Lighter: sends data to the lights
  
  11/11/15
  
  Built on glorious Spheres Simulator
  
  x,y coordinates are weird for each sphere
  x = FACE of the dodecahedron (0-11)
  y = PANEL within the FACE (0-9)
  
  Turn on the coordinates to see the system.
  
  Number of Big Spheres set by numBigSphere. 
  
  Function included to translate x,y coordinates into strand light.
  
*/

// Sphere constants
final byte numBigSphere = 1;  // Number of Big Spheres
final int NUM_PIXELS = 120;   // Lights per sphere
final int FACES = 12;
final int PANELS = 10;
final int VERTICES = 5;  // per face
final float A = 1.618033989; // (1 * sqr(5) / 2)
final float B = 0.618033989; // 1 / (1 * sqr(5) / 2)
final float radius = 1.7320508;  // Vector distance from center to edge

// One shape per triangle panel
PShape[][] tri_shapes = new PShape[FACES][PANELS];

// Center point of each panel - needed to position text labels
//float[][][][] vertex = new float[FACES][PANELS][3][3];
PVector[][] centers = new PVector[FACES][PANELS];

PVector[] vert = new PVector[20]; // list of vertices
int[][] faces =  new int[FACES][VERTICES];  // list of faces (joining vertices)

//
// Pixel pusher functions
import com.heroicrobot.dropbit.registry.*;
import com.heroicrobot.dropbit.devices.pixelpusher.Pixel;
import com.heroicrobot.dropbit.devices.pixelpusher.Strip;
import com.heroicrobot.dropbit.devices.pixelpusher.PixelPusher;
import com.heroicrobot.dropbit.devices.pixelpusher.PusherCommand;

import processing.net.*;
import java.util.*;
import java.util.regex.*;

// network vars
int port = 4444;
Server _server; 
StringBuffer _buf = new StringBuffer();

class TestObserver implements Observer {
  public boolean hasStrips = false;
  public void update(Observable registry, Object updatedDevice) {
    println("Registry changed!");
    if (updatedDevice != null) {
      println("Device change: " + updatedDevice);
    }
    this.hasStrips = true;
  }
}

TestObserver testObserver;

// Physical strip registry
DeviceRegistry registry;
List<Strip> strips = new ArrayList<Strip>();

// Draw labels has 3 states:
// 0:LED number, 1:(x,y) coordinate, and 2:none
int DRAW_LABELS = 2;
int BRIGHTNESS = 100;  // A percentage
int COLOR_STATE = 0;  // no enum types in processing. Messy

// TILING
// true: show all roses and let each rose act differently
// false: show only one rose (0) and force all roses to act the same way
boolean TILING = false;  // Tiling!

// Two buffers permits updating only the lights that change color
// May improve performance and reduce flickering
byte[][][] curr_buffer = new byte[numBigSphere][NUM_PIXELS][3];
byte[][][] next_buffer = new byte[numBigSphere][NUM_PIXELS][3];
byte[][][] morph_buffer = new byte[numBigSphere][NUM_PIXELS][3];
color[][] pix_color = new color[numBigSphere][NUM_PIXELS];

// Calculated pixel constants for simulator display
boolean UPDATE_VISUALIZER = false;  // turn false for LED-only updates
int SCREEN_SIZE = 400;  // square screen
float SPHERE_SIZE = SCREEN_SIZE / 10;
float LABEL_DIST = SPHERE_SIZE * 1.1;
float BORDER = 0.05; // How much fractional edge between sphere and screen
int BORDER_PIX = int(SCREEN_SIZE * BORDER); // Edge in pixels

//
// Setup
//
void setup() {
  
  size(SCREEN_SIZE, SCREEN_SIZE + 50, P3D); // 50 for controls
  camera(0,0,160, 0,0,0, 0,1,0);
  
  frameRate(10); // default 60 seems excessive
  
  CalculateSphere();
  
  registry = new DeviceRegistry();
  testObserver = new TestObserver();
  registry.addObserver(testObserver);
  colorMode(RGB, 255);
  frameRate(60);
  prepareExitHandler();
  strips = registry.getStrips();  // Array of strips?
  
  initializeColorBuffers();  // Stuff with zeros (all black)
  
  _server = new Server(this, port);
  println("server listening:" + _server);
}

void draw() {
 
  pollServer();        // Get messages from python show runner
  background(200);
  
  // Rotate the sphere
  pushMatrix();
  rotateY(map(mouseX,0,width,0,2*PI));
  rotateX(map (mouseY,0,height,0,2*PI));
  drawSpheres();
  drawLabels();
  popMatrix();
  
  // Fix this!
  drawBottomControls();
}

void drawCheckbox(int x, int y, int size, color fill, boolean checked) {
  stroke(0);
  fill(fill);  
  rect(x,y,size,size);
  if (checked) {    
    line(x,y,x+size,y+size);
    line(x+size,y,x,y+size);
  }  
}

void drawBottomControls() {
  // draw a bottom white region
  fill(255,255,255);
  rect(0,SCREEN_SIZE,SCREEN_SIZE,40);
  
  // draw divider lines
  stroke(0);
  line(140,SCREEN_SIZE,140,SCREEN_SIZE+40);
  line(290,SCREEN_SIZE,290,SCREEN_SIZE+40);
  line(470,SCREEN_SIZE,470,SCREEN_SIZE+40);
  
  // draw checkboxes
  stroke(0);
  fill(255);
  
  // Checkbox is always unchecked; it is 3-state
  rect(20,SCREEN_SIZE+10,20,20);  // label checkbox
  
  rect(200,SCREEN_SIZE+4,15,15);  // minus brightness
  rect(200,SCREEN_SIZE+22,15,15);  // plus brightness
  
  drawCheckbox(340,SCREEN_SIZE+4,15, color(255,0,0), COLOR_STATE == 1);
  drawCheckbox(340,SCREEN_SIZE+22,15, color(255,0,0), COLOR_STATE == 4);
  drawCheckbox(360,SCREEN_SIZE+4,15, color(0,255,0), COLOR_STATE == 2);
  drawCheckbox(360,SCREEN_SIZE+22,15, color(0,255,0), COLOR_STATE == 5);
  drawCheckbox(380,SCREEN_SIZE+4,15, color(0,0,255), COLOR_STATE == 3);
  drawCheckbox(380,SCREEN_SIZE+22,15, color(0,0,255), COLOR_STATE == 6);
  
  drawCheckbox(400,SCREEN_SIZE+10,20, color(255,255,255), COLOR_STATE == 0);  
  
  // draw text labels in 12-point Helvetica
  fill(0);
  textAlign(LEFT);
  PFont f = createFont("Helvetica", 12, true);
  textFont(f, 12);  
  text("Labels", 50, SCREEN_SIZE+25);
  
  text("-", 190, SCREEN_SIZE+16);
  text("+", 190, SCREEN_SIZE+34);
  text("Brightness", 225, SCREEN_SIZE+25);
  textFont(f, 20);
  text(BRIGHTNESS, 150, SCREEN_SIZE+28);
  
  textFont(f, 12);
  text("None", 305, SCREEN_SIZE+16);
  text("All", 318, SCREEN_SIZE+34);
  text("Color", 430, SCREEN_SIZE+25);
  
  int font_size = 12;  // default size
  f = createFont("Arial", font_size, true);
  textFont(f, font_size);
}

void mouseClicked() {  
  println("click! x:" + mouseX + " y:" + mouseY);
  if (mouseX > 20 && mouseX < 40 && mouseY > SCREEN_SIZE+10 && mouseY < SCREEN_SIZE+30) {
    // clicked draw labels button
    DRAW_LABELS = (DRAW_LABELS + 1) % 3;
   
  }  else if (mouseX > 200 && mouseX < 215 && mouseY > SCREEN_SIZE+4 && mouseY < SCREEN_SIZE+19) {
    // Bright down checkbox
    BRIGHTNESS -= 5;  
    if (BRIGHTNESS < 1) BRIGHTNESS = 1;
   
  } else if (mouseX > 200 && mouseX < 215 && mouseY > SCREEN_SIZE+22 && mouseY < SCREEN_SIZE+37) {
    // Bright up checkbox
    if (BRIGHTNESS <= 95) BRIGHTNESS += 5;
  
  }  else if (mouseX > 400 && mouseX < 420 && mouseY > SCREEN_SIZE+10 && mouseY < SCREEN_SIZE+30) {
    // No color correction  
    COLOR_STATE = 0;
   
  }  else if (mouseX > 340 && mouseX < 355 && mouseY > SCREEN_SIZE+4 && mouseY < SCREEN_SIZE+19) {
    // None red  
    COLOR_STATE = 1;
   
  }  else if (mouseX > 340 && mouseX < 355 && mouseY > SCREEN_SIZE+22 && mouseY < SCREEN_SIZE+37) {
    // All red  
    COLOR_STATE = 4;
   
  }  else if (mouseX > 360 && mouseX < 375 && mouseY > SCREEN_SIZE+4 && mouseY < SCREEN_SIZE+19) {
    // None blue  
    COLOR_STATE = 2;
   
  }  else if (mouseX > 360 && mouseX < 375 && mouseY > SCREEN_SIZE+22 && mouseY < SCREEN_SIZE+37) {
    // All blue  
    COLOR_STATE = 5;
   
  }  else if (mouseX > 380 && mouseX < 395 && mouseY > SCREEN_SIZE+4 && mouseY < SCREEN_SIZE+19) {
    // None green  
    COLOR_STATE = 3;
   
  }  else if (mouseX > 380 && mouseX < 395 && mouseY > SCREEN_SIZE+22 && mouseY < SCREEN_SIZE+37) {
    // All green  
    COLOR_STATE = 6;
  }
}

// Coord class

class Coord {
  public int x, y;
  
  Coord(int x, int y) {
    this.x = x;
    this.y = y;
  }
}

//
// Converts an x,y triangle coordinate into a light number
//
char GetLightFromCoord(byte s, byte f, byte p) {
  
  // Fill in
  return (char)((f * PANELS) + p);
}

Coord GetCoordFromLED(char LED) {
  
  // Fill in
  return (new Coord(LED / FACES, LED % FACES));
}

//
// drawLabels - Draw a (x,y) text label above each panel
//
void drawLabels() {
  if (TILING) {
    for (byte i = 0; i < numBigSphere; i++) {
      draw_label(i);
    }
  } else {
    draw_label(byte(0));
  }
}

// Draw a (x,y) text label above each panel
void draw_label(byte s) {
  if (DRAW_LABELS == 2) return;
  
  String text_coord;
  Coord coord;
  
  fill(255);  // Gray
  textAlign(CENTER);
  textMode(SHAPE);
  PFont label_font = createFont("Helvetica", 6, true);
  textFont(label_font, 6); 
  
  for (byte f = 0; f < 12; f++) {
    for (byte p = 0; p < 10; p++) {
      if (DRAW_LABELS == 0) {
        text_coord = String.format("%d", byte(GetLightFromCoord(byte(0),f,p)));
      } else {
        text_coord = String.format("%d,%d", f, p);
      }
      text(text_coord, centers[f][p].x, centers[f][p].y, centers[f][p].z);
    }
  }
}

//
// Fill in the simulator all at once. This approach may be faster than individual updates
//
void drawSpheres() {
  byte s = 0;
  
  for (byte f = 0; f < FACES; f++) {
    for (byte p = 0; p < PANELS; p++) {
      draw_panel(s,f,p, pix_color[0][GetLightFromCoord(s,f,p)]);
    }
  }
}
   
void setCellColor(color c, byte s, int i) {
  if (i >= NUM_PIXELS) {
    println("invalid LED number: i only have " + NUM_PIXELS + " LEDs");
    return;
  }
  if (s >= numBigSphere) {
    println("invalid rose number: i only have " + numBigSphere + " Roses");
    return;
  }
  pix_color[s][i] = c;
}


//
//  Server Routines
//
void pollServer() {
  try {
    Client c = _server.available();
    // append any available ints to the buffer
    if (c != null) {
      _buf.append(c.readString());
    }
    // process as many lines as we can find in the buffer
    int ix = _buf.indexOf("\n");
    while (ix > -1) {
      String msg = _buf.substring(0, ix);
      msg = msg.trim();
      //println(msg);
      processCommand(msg);
      _buf.delete(0, ix+1);
      ix = _buf.indexOf("\n");
    }
  } catch (Exception e) {
    println("exception handling network command");
    e.printStackTrace();
  }  
}

Pattern cmd_pattern = Pattern.compile("^\\s*(\\d+),(\\d+),(\\d+),(\\d+),(\\d+)\\s*$");

void processCommand(String cmd) {
  // morphing
  if (cmd.charAt(0) == 'M') {
    goMorphing(Integer.valueOf(cmd.substring(1, cmd.length())));
  
  // Pixel command
  } else {  
    processPixelCommand(cmd);
  }
}

void processPixelCommand(String cmd) {
  Matcher m = cmd_pattern.matcher(cmd);
  if (!m.find()) {
    println("ignoring input!");
    return;
  }
  byte sphere  = Byte.valueOf(m.group(1));
  int pix    = Integer.valueOf(m.group(2));
  int r     = Integer.valueOf(m.group(3));
  int g     = Integer.valueOf(m.group(4));
  int b     = Integer.valueOf(m.group(5));
  
  sendColorOut(sphere, pix, byte(r), byte(g), byte(b), false);  
//  println(String.format("setting pixel:%d,%d to r:%d g:%d b:%d", rose, pix, r, g, b));
}

// Process a morph command - Push the frame buffer on to the lights
void goMorphing(int morph) {
  morph_frame(morph);
  sendDataToLights();
  if (morph == 10) {
    pushColorBuffer();   // Push the frame buffers: next -> current
  }
}

// Send a corrected color to a sphere pixel on screen and in lights
void sendColorOut(byte sphere, int pix, byte r, byte g, byte b, boolean morph) {
  if (sphere > 0 || pix > 119) {
    return;
  }
  
  color correct = colorCorrect(r,g,b);
  
  r = adj_brightness(red(correct));
  g = adj_brightness(green(correct));
  b = adj_brightness(blue(correct));
  
  setCellColor(color(r,g,b), sphere, pix);  // Simulator
  setPixelBuffer(sphere, pix, r, g, b, morph);  // Lights: sets next-frame buffer (doesn't turn them on)
}

//
//  Fractional morphing between current and next frame - sends data to lights
//
//  morph is an integer representation morph/10 fraction towards the next fram
//
void morph_frame(int morph) {
  byte sphere, r,g,b;
  int pix;
  float fract = morph / 10.0;
  
  for (sphere = 0; sphere < numBigSphere; sphere++) {
    for (pix = 0; pix < NUM_PIXELS; pix++) {
      if (hasChanged(sphere, pix)) {
        r = interp(curr_buffer[sphere][pix][0], next_buffer[sphere][pix][0], fract);
        g = interp(curr_buffer[sphere][pix][1], next_buffer[sphere][pix][1], fract);
        b = interp(curr_buffer[sphere][pix][2], next_buffer[sphere][pix][2], fract);
        
        sendColorOut(sphere, pix, r, g, b, true);
      }
    }
  }
}  

byte interp(byte a, byte b, float fract) {
  return (byte(a + (fract * (b-a))));
}

//
//  Routines to interact with the Lights
//
void sendDataToLights() {
  byte BigSphere;
  int pixel;
  
  if (testObserver.hasStrips) {   
    registry.startPushing();
    registry.setExtraDelay(0);
    registry.setAutoThrottle(true);
    registry.setAntiLog(true);    
    
    List<Strip> strips = registry.getStrips();
    BigSphere = 0;
    
    for (Strip strip : strips) {      
      for (pixel = 0; pixel < NUM_PIXELS; pixel++) {
         if (hasChanged(BigSphere,pixel)) {
           strip.setPixel(getPixelBuffer(BigSphere,pixel), pixel);
         }
      }
      BigSphere++;
      if (BigSphere >=numBigSphere) break;  // Prevents buffer overflow
    }
  }
}

private void prepareExitHandler () {

  Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {

    public void run () {

      System.out.println("Shutdown hook running");

      List<Strip> strips = registry.getStrips();
      for (Strip strip : strips) {
        for (int i=0; i<strip.getLength(); i++)
          strip.setPixel(#000000, i);
      }
      for (int i=0; i<100000; i++)
        Thread.yield();
    }
  }
  ));
}

//
//  Routines for the strip buffer
//
byte adj_brightness(float value) {
  return (byte)(value * BRIGHTNESS / 100);
}

color colorCorrect(int r, int g, int b) {
  switch(COLOR_STATE) {
    case 1:  // no red
      if (r > 0) {
        if (g == 0) {
          g = r;
          r = 0;
        } else if (b == 0) {
          b = r;
          r = 0;
        }
      }
      break;
    
    case 2:  // no green
      if (g > 0) {
        if (r == 0) {
          r = g;
          g = 0;
        } else if (b == 0) {
          b = g;
          g = 0;
        }
      }
      break;
    
    case 3:  // no blue
      if (b > 0) {
        if (r == 0) {
          r = b;
          b = 0;
        } else if (g == 0) {
          g = b;
          b = 0;
        }
      }
      break;
    
    case 4:  // all red
      if (r == 0) {
        if (g > b) {
          r = g;
          g = 0;
        } else {
          r = b;
          b = 0;
        }
      }
      break;
    
    case 5:  // all green
      if (g == 0) {
        if (r > b) {
          g = r;
          r = 0;
        } else {
          g = b;
          b = 0;
        }
      }
      break;
    
    case 6:  // all blue
      if (b == 0) {
        if (r > g) {
          b = r;
          r = 0;
        } else {
          b = g;
          g = 0;
        }
      }
      break;
    
    default:
      break;
  }
  return color(r,g,b);   
}

// Fill color buffers with zeros 
void initializeColorBuffers() {
  byte empty = 0;
  for (byte s = 0; s < numBigSphere; s++) {
    for (int p = 0; p < NUM_PIXELS; p++) {
      setPixelBuffer(s, p, empty,empty,empty, false);
    }
  }
  pushColorBuffer();
}

void setPixelBuffer(byte BigSphere, int pixel, byte r, byte g, byte b, boolean morph) {
  BigSphere = byte(BigSphere % numBigSphere);
  pixel = int(pixel % NUM_PIXELS);
  
  if (morph) {
    morph_buffer[BigSphere][pixel][0] = r;
    morph_buffer[BigSphere][pixel][1] = g;
    morph_buffer[BigSphere][pixel][2] = b;
  } else {
    next_buffer[BigSphere][pixel][0] = r;
    next_buffer[BigSphere][pixel][1] = g;
    next_buffer[BigSphere][pixel][2] = b;
  }
}

color getPixelBuffer(byte BigSphere, int pixel) {
  BigSphere = byte(BigSphere % numBigSphere);
  pixel = int(pixel % NUM_PIXELS);
  
  return color(next_buffer[BigSphere][pixel][0],
               next_buffer[BigSphere][pixel][1],
               next_buffer[BigSphere][pixel][2]);
}

boolean hasChanged(int t, int p) {
  if (curr_buffer[t][p][0] != next_buffer[t][p][0] ||
      curr_buffer[t][p][1] != next_buffer[t][p][1] ||
      curr_buffer[t][p][2] != next_buffer[t][p][2]) {
        return true;
      } else {
        return false;
      }
}

void pushColorBuffer() {
  for (byte s = 0; s < numBigSphere; s++) {
    for (int p = 0; p < NUM_PIXELS; p++) {
      curr_buffer[s][p][0] = next_buffer[s][p][0];
      curr_buffer[s][p][1] = next_buffer[s][p][1];
      curr_buffer[s][p][2] = next_buffer[s][p][2]; 
    }
  }
}

//
// Calculate Sphere
//
// Routines called just once in set-up to calculate the sphere's screen vertices
// Probably don't need to save values as globals, but doing so is convenient and
// does not take up much memory
void CalculateSphere() {
  MapVertices();
  
  for (int face=0; face<12; face++) {
    DivideFace(face);
  }
}

//
// DivideFace
//
// Calculate the 10 Panels within each Dodecahedron face
void DivideFace(int face) {
  PVector[] corners = new PVector[5];
  PVector center, half;
  
  for (int i=0; i<5; i++) {  // Shorthand conversion to save typing
    corners[i] = vert[faces[face][i]];
  }
  
  half = PVector.lerp(corners[0], corners[1], 0.5);
  center = PVector.lerp(half, corners[3], 0.447);  // 0.809 / (1 + 0.809)
  center.setMag(radius);
  
  for (int i=0; i<5; i++) {
    half = PVector.lerp(corners[i], corners[(i+1)%5], 0.5);
    half.setMag(radius);
    
    // Record the panel center to position labels 
    SaveCenter(face, i*2, corners[i], half, center);
    SaveCenter(face, (i*2)+1, corners[(i+1)%5], half, center);
    
    // Save the panel shape
    SaveShape(face, i*2, corners[i], half, center);
    SaveShape(face, (i*2)+1, corners[(i+1)%5], half, center);
  }
}

//
// SaveCenter - Record the center of each panel for the label
//
void SaveCenter(int face, int panel, PVector p1, PVector p2, PVector p3) {
  centers[face][panel] = new PVector(LABEL_DIST * (p1.x + p2.x + p3.x) / 3,
                                     LABEL_DIST * (p1.y + p2.y + p3.y) / 3,
                                     LABEL_DIST * (p1.z + p2.z + p3.z) / 3);
}

void SaveShape(int face, int panel, PVector p1, PVector p2, PVector p3) {
  tri_shapes[face][panel] = createShape();
  tri_shapes[face][panel].beginShape();
  
  tri_shapes[face][panel].vertex(p1.x * SPHERE_SIZE, p1.y * SPHERE_SIZE, p1.z * SPHERE_SIZE);
  tri_shapes[face][panel].vertex(p2.x * SPHERE_SIZE, p2.y * SPHERE_SIZE, p2.z * SPHERE_SIZE);
  tri_shapes[face][panel].vertex(p3.x * SPHERE_SIZE, p3.y * SPHERE_SIZE, p3.z * SPHERE_SIZE);
  
  tri_shapes[face][panel].endShape(CLOSE);
}

void draw_panel(byte sphere, byte face, byte panel, color c) {
  tri_shapes[face][panel].setStroke(127);
  tri_shapes[face][panel].setFill(c);
  shape(tri_shapes[face][panel]);
}

//
// MapVertices
//
// Map how the dodehedron faces are connected
void MapVertices() {
  vert[ 0] = new PVector(1, 1, 1);
  vert[ 1] = new PVector(1, 1, -1);
  vert[ 2] = new PVector(1, -1, 1);
  vert[ 3] = new PVector(1, -1, -1);
  vert[ 4] = new PVector(-1, 1, 1);
  vert[ 5] = new PVector(-1, 1, -1);
  vert[ 6] = new PVector(-1, -1, 1);
  vert[ 7] = new PVector(-1, -1, -1);
  
  vert[ 8] = new PVector(0, B, A);
  vert[ 9] = new PVector(0, B, -A);
  vert[10] = new PVector(0, -B, A);
  vert[11] = new PVector(0, -B, -A);
  
  vert[12] = new PVector(B, A, 0);
  vert[13] = new PVector(B, -A, 0);
  vert[14] = new PVector(-B, A, 0);
  vert[15] = new PVector(-B, -A, 0);
  
  vert[16] = new PVector(A, 0, B);
  vert[17] = new PVector(A, 0, -B);
  vert[18] = new PVector(-A, 0, B);
  vert[19] = new PVector(-A, 0, -B);
    
  faces[ 0] = new int[] {0, 16, 2, 10, 8};
  faces[ 1] = new int[] {0, 8, 4, 14, 12};
  faces[ 2] = new int[] {16, 17, 1, 12, 0};
  faces[ 3] = new int[] {1, 9, 11, 3, 17};
  faces[ 4] = new int[] {1, 12, 14, 5, 9};
  faces[ 5] = new int[] {2, 13, 15, 6, 10};
  faces[ 6] = new int[] {13, 3, 17, 16, 2};
  faces[ 7] = new int[] {3, 11, 7, 15, 13};
  faces[ 8] = new int[] {4, 8, 10, 6, 18};
  faces[ 9] = new int[] {14, 5, 19, 18, 4};
  faces[10] = new int[] {5, 19, 7, 11, 9};
  faces[11] = new int[] {15, 7, 19, 18, 6};
}
