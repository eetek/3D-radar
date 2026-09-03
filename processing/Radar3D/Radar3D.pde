import processing.serial.*;

Serial myPort;
String portName = "dev/cu.usbmodem2101"; //change this to your own port

String data = "";
int index1, index2;

int panAngle, tiltAngle, dist;

// Must match the Arduino sketch's sweep ranges
final int panMin = 15, panMax = 165;
final int tiltMin = 30, tiltMax = 90;
final int levelTilt = 60;

final float maxRangeCm = 100; // ignore serial data farther than this (can be changed)

// one 3D point per (pan, tilt) reading we've received
ArrayList<PVector> points = new ArrayList<PVector>();
ArrayList<Integer>  pointDist = new ArrayList<Integer>();
final int MAX_POINTS = 4000; // cap so old points fade out of the cloud

// orbit control state
float rotY = -0.6;
float rotX = 0.35;
float zoom = 1.0;

void setup() {
  size(1100, 800, P3D); // enable 3D renderer

  println(Serial.list());
  //String portName = Serial.list()[0];
  myPort = new Serial(this, portName, 115200);
  myPort.bufferUntil('.');
}

void draw() {
  background(0);

  translate(width/2, height/2, -200);
  scale(zoom);
  rotateX(rotX);
  rotateY(rotY);

  drawFrame();
  drawPointCloud();
  drawCurrentSweepLine();

  hint(DISABLE_DEPTH_TEST); // draw text on top
  camera();
  drawHUD();
  hint(ENABLE_DEPTH_TEST);
}

// Convert a (panAngle, tiltAngle, distance) reading into an (x, y, z) point.
// pan  -> sweeps left/right in the horizontal plane (x/z)
// tilt -> elevation, sweeps up/down (y). Processing's y-axis points DOWN,
// so we negate it to make "up" visually up.
PVector toXYZ(float pan, float tilt, float d) {
  float azimuth   = radians(pan);
  float elevation = radians(tilt - levelTilt);

  float x =  d * cos(elevation) * cos(azimuth);
  float z = -d * cos(elevation) * sin(azimuth);
  float y = -d * sin(elevation);
  return new PVector(x, y, z);
}

void serialEvent(Serial p) {
  data = p.readStringUntil('.');
  if (data == null) return;
  data = data.substring(0, data.length() - 1);

  index1 = data.indexOf(",");
  index2 = data.indexOf(",", index1 + 1);
  if (index1 == -1 || index2 == -1) return; // malformed record, skip it

  panAngle  = int(data.substring(0, index1));
  tiltAngle = int(data.substring(index1 + 1, index2));
  dist      = int(data.substring(index2 + 1, data.length()));

  if (dist > 0 && dist <= maxRangeCm) {
    points.add(toXYZ(panAngle, tiltAngle, dist));
    pointDist.add(dist);
    if (points.size() > MAX_POINTS) {
      points.remove(0);
      pointDist.remove(0);
    }
  }
}

void drawPointCloud() {
  noStroke();
  for (int i = 0; i < points.size(); i++) {
    PVector pt = points.get(i);
    // color/size by distance: closer = brighter, further = dimmer
    float t = map(pointDist.get(i), 0, maxRangeCm, 1, 0.3);
    fill(98 * t, 245 * t, 31 * t);
    pushMatrix();
    translate(pt.x, pt.y, pt.z);
    sphere(2.5);
    popMatrix();
  }
}

void drawCurrentSweepLine() {
  // shows the sensor's current pan/tilt heading as a bright sweeping line
  stroke(30, 250, 60);
  strokeWeight(3);
  PVector tip = toXYZ(panAngle, tiltAngle, maxRangeCm);
  line(0, 0, 0, tip.x, tip.y, tip.z);
}

void drawFrame() {
  stroke(60);
  noFill();
  // simple range rings on the ground plane for a sense of scale
  pushMatrix();
  rotateX(HALF_PI);
  for (int r = 20; r <= maxRangeCm; r += 20) {
    ellipse(0, 0, r * 2, r * 2);
  }
  popMatrix();
}

void drawHUD() {
  fill(98, 245, 31);
  textSize(20);
  text("SciCraft 3D Radar", 20, 30);
  text("Pan: " + panAngle + "\u00B0   Tilt: " + tiltAngle + "\u00B0   Dist: " + dist + " cm", 20, 55);
  text("Points: " + points.size(), 20, 80);
  text("Drag mouse to orbit, scroll to zoom", 20, height - 20);
}

void mouseDragged() {
  rotY += (mouseX - pmouseX) * 0.01;
  rotX -= (mouseY - pmouseY) * 0.01;
}

void mouseWheel(MouseEvent event) {
  zoom -= event.getCount() * 0.05;
  zoom = constrain(zoom, 0.3, 3.0);
}
