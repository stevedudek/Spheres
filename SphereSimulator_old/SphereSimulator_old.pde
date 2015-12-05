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
  
  Number of Big Spheres set by numBigSphere. Each Big Spheres needs
  an (x,y) coordinate and a (L,R) connector designation. 
  
  Function included to translate x,y coordinates into strand light.
  
*/

// Sphere constants
final int numBigSphere = 1;  // Number of Big Spheres
final int NUM_PIXELS = 120;  // Lights per sphere
final int FACES = 12;
final int PANELS = 10;
final int VERTICES = 5;  // per face
final float A = 1.618033989; // (1 * sqr(5) / 2) - wikipedia
final float B = 0.618033989; // 1 / (1 * sqr(5) / 2) - wikipedia
final float radius = 1.7320508;  // Vector distance from center to edge

// All the point coordinates for the visualizer are stored here
float[][][][] vertex = new float[FACES][PANELS][3][3];

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

final int NONE = 9999;  // hack: "null" for "int'

//
// Controller on the bottom of the screen
//
// Draw labels has 3 states:
// 0:LED number, 1:(x,y) coordinate, and 2:none
int DRAW_LABELS = 2;
int BRIGHTNESS = 100;  // A percentage
int COLOR_STATE = 0;  // no enum types in processing. Messy

// Two buffers permits updating only the lights that change color
// May improve performance and reduce flickering
int[][][] curr_buffer = new int[numBigSphere][NUM_PIXELS][3];
int[][][] next_buffer = new int[numBigSphere][NUM_PIXELS][3];

// Calculated pixel constants for simulator display
boolean UPDATE_VISUALIZER = false;  // turn false for LED-only updates
int SCREEN_SIZE = 600;  // square screen
float SPHERE_SIZE = SCREEN_SIZE / 20;
float BORDER = 0.05; // How much fractional edge between sphere and screen
int BORDER_PIX = int(SCREEN_SIZE * BORDER); // Edge in pixels
int CORNER_X = 10; // bottom left corner position on the screen
int CORNER_Y = SCREEN_SIZE - 10; // bottom left corner position on the screen

// Grid model(s) of Big Spheres
SphereForm[] sphereGrid = new SphereForm[numBigSphere];


void setup() {
  size(SCREEN_SIZE, SCREEN_SIZE + 50, P3D); // 50 for controls
  camera(0,0,160, 0,0,0, 0,1,0);
  stroke(0);
  fill(255,255,0);
  
  frameRate(10); // default 60 seems excessive
  
  CalculateSphere();
  
  // Set up the Big Spheres and stuff in the little sphere
  for (int i = 0; i < numBigSphere; i++) {
    sphereGrid[i] = makeSphereGrid(0,0,i);
  }
  
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
 
  background(200);
  
  // Rotate the sphere
  pushMatrix();
  rotateY(map(mouseX,0,width,0,2*PI));
  rotateX(map (mouseY,0,height,0,2*PI));
  
  // Draw each grid
  for (int i = 0; i < numBigSphere; i++) {
    sphereGrid[i].draw();
  }
  popMatrix();
  
  drawBottomControls();
  
  pollServer();        // Get messages from python show runner
  sendDataToLights();  // Dump data into lights
  pushColorBuffer();   // Push the frame buffers
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
  text("Toggle Labels", 50, SCREEN_SIZE+25);
  
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
  f = createFont("Helvetica", font_size, true);
  textFont(f, font_size);
}

void mouseClicked() {  
  //println("click! x:" + mouseX + " y:" + mouseY);
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
// for grid number grid
//

int GetLightFromCoord(int x, int y, int grid) {
  
  // Fill in
  
  return x;
}

SphereForm makeSphereGrid(int big_x, int big_y, int big_num) {
  
  SphereForm form = new SphereForm();
  
  for (int y=0; y<PANELS; y++) {
    for (int x=0; x<FACES; x++) {
      form.add(new Sphere(x,y, big_num));
    }
  }
  return form;  
}


class SphereForm {
  ArrayList<Sphere> spheres;
  
  SphereForm() {
    spheres = new ArrayList<Sphere>();
  }
  
  void add(Sphere t) {
    int sphereId = spheres.size();
    spheres.add(t);
  }
  
  int size() {
    return spheres.size();
  }
  
  void draw() {
    for (Sphere s : spheres) {
      s.draw();
    }
  }
  
  void setCellColor(color c, int i) {
    if (i >= spheres.size()) {
      // println("invalid offset for SphereForm.setColor: i only have " + spheres.size() + " sphere");
      return;
    }
    for (Sphere s : spheres) {  // Search all 
      if (i == s.LED) {  // for the one that has the correct LED#
        s.setColor(c);
        return;
      }
    }
    println("Could not find LED #"+i);
  }
}

class Sphere {
  String id = null; // "xcoord, ycoord"
  int xcoord;  // Face
  int ycoord;  // Panel
  int big_num; // strip number
  int LED;     // LED number on the strand
  color c;
  
  Sphere(int xcoord, int ycoord, int big_num) {
    this.xcoord = xcoord;
    this.ycoord = ycoord;
    this.big_num = big_num;
    this.LED = (xcoord * PANELS) + ycoord;
    this.c = color(255,255,255);
    
    // str(xcoord + ", " + ycoord)
    int[] coords = new int[2];
    coords[0] = xcoord;
    coords[1] = ycoord;
    this.id = join(nf(coords, 0), ",");
  }

  void setId(String id) {
    this.id = id;
  }
  
  void setColor(color c) {
    this.c = c;
  }

  void draw() {
    fill(c);
    stroke(125);  // gray border
    
    beginShape();
    for (int i = 0; i < 3; i++) {
      vertex(vertex[xcoord][ycoord][i][0]*SPHERE_SIZE, vertex[xcoord][ycoord][i][1]*SPHERE_SIZE, vertex[xcoord][ycoord][i][2]*SPHERE_SIZE);
    }
    endShape(CLOSE);
  }
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
Pattern osc_pattern = Pattern.compile("^\\s*(\\w+),(\\w+),(\\d+)\\s*$");

void processCommand(String cmd) {
  Matcher m = cmd_pattern.matcher(cmd);  // For RGB commands
  Matcher o = osc_pattern.matcher(cmd);  // For OSC commands
  
  if (m.find()) {
    Process_RGB_command(m);
  } else if (o.find()) {
    Process_OSC_command(o);
  } else {
    println(cmd);
    println("ignoring input!");
    return;
  }
}

void Process_RGB_command(Matcher m) {
  int sphere = Integer.valueOf(m.group(1));
  int pix    = Integer.valueOf(m.group(2));
  int r      = Integer.valueOf(m.group(3));
  int g      = Integer.valueOf(m.group(4));
  int b      = Integer.valueOf(m.group(5));
  
  // println(String.format("setting pixel:%d,%d to r:%d g:%d b:%d", sphere, pix, r, g, b));
  
  sendColorOut(sphere, pix, r, g, b, false);
}

// Send a corrected color to a sphere pixel on screen and in lights
void sendColorOut(int sphere, int pix, int r, int g, int b, boolean morph) {
  if (sphere > 0 || pix > 119) {
    return;
  }
  
  color correct = colorCorrect(r,g,b);
  
  r = adj_brightness(red(correct));
  g = adj_brightness(green(correct));
  b = adj_brightness(blue(correct));
  
  sphereGrid[sphere].setCellColor(color(r,g,b), pix);  // Simulator
  setPixelBuffer(sphere, pix, r, g, b, morph);  // Lights: sets next-frame  
}

void Process_OSC_command(Matcher o) {
  String osc  = String.valueOf(o.group(1));
  String cmd  = String.valueOf(o.group(2));
  int value   = Integer.valueOf(o.group(3));
  
  if (!osc.equals("OSC")) {
    println("Did not receive an OSC header for: %s, %s, %d", osc, cmd, value);
  } else {
    if (cmd.equals("color")) {
      COLOR_STATE = value;
    } else if (cmd.equals("brightness")) {
      BRIGHTNESS = value;
    }
  }
}

//
//  Routines to interact with the Lights
//

void sendDataToLights() {
  int BigSphere, pixel;
  
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

int adj_brightness(float value) {
  return (int)(value * BRIGHTNESS / 100);
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

void initializeColorBuffers() {
  for (int t = 0; t < numBigSphere; t++) {
    for (int p = 0; p < NUM_PIXELS; p++) {
      setPixelBuffer(t, p, 0,0,0, false);
    }
  }
  pushColorBuffer();
}

void setPixelBuffer(int BigSphere, int pixel, int r, int g, int b, boolean morph) {
  BigSphere = bounds(BigSphere, 0, numBigSphere-1);
  pixel = bounds(pixel, 0, NUM_PIXELS-1);
  
  next_buffer[BigSphere][pixel][0] = r;
  next_buffer[BigSphere][pixel][1] = g;
  next_buffer[BigSphere][pixel][2] = b;
}

color getPixelBuffer(int BigSphere, int pixel) {
  BigSphere = bounds(BigSphere, 0, numBigSphere-1);
  pixel = bounds(pixel, 0, NUM_PIXELS-1);
  
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
  for (int t = 0; t < numBigSphere; t++) {
    for (int p = 0; p < NUM_PIXELS; p++) {
      curr_buffer[t][p][0] = next_buffer[t][p][0];
      curr_buffer[t][p][1] = next_buffer[t][p][1];
      curr_buffer[t][p][2] = next_buffer[t][p][2]; 
    }
  }
}

int bounds(int value, int minimun, int maximum) {
  if (value < minimun) return minimun;
  if (value > maximum) return maximum;
  return value;
}

//
// Calculate Sphere
//
// Routines called just once in set-up to calculate the sphere's screen vertices 
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
  
  for (int i=0; i<5; i++) {
    corners[i] = vert[faces[face][i]];
  }
  
  half = PVector.lerp(corners[0], corners[1], 0.5);
  center = PVector.lerp(half, corners[3], 0.447);  // 0.809 / (1 + 0.809)
  center.setMag(radius);
  
  for (int i=0; i<5; i++) {
    half = PVector.lerp(corners[i], corners[(i+1)%5], 0.5);
    half.setMag(radius);
    SaveVertices(face, i*2, corners[i], half, center);
    SaveVertices(face, (i*2)+1, corners[(i+1)%5], half, center);
  }
}

//
// SaveVertices
//
// Stores a triangle from the 3 PVectors
void SaveVertices(int face, int panel, PVector p1, PVector p2, PVector p3) {
  vertex[face][panel][0] = p1.array();
  vertex[face][panel][1] = p2.array();
  vertex[face][panel][2] = p3.array();
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
