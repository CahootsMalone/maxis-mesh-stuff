/*
Maxis Mesh Viewer
Author: Cahoots Malone

INSTRUCTIONS
1. Set the variables starting with "PATH" in the "values to set" block, below.
2. Run the sketch.
3. Controls:
  a. Right/left arrow keys: Go to next/previous mesh in file.
  b. Hold left mouse button and drag: Rotate camera.
  c. Scroll mouse wheel: Zoom in/out.
  d. V key: Hide/show vertices and edges.
  e. G key: Hide/show coordinate frame gizmo.
  f. O key: Toggle rotation around mesh origin/world origin.
4. Advanced controls:
  a. Up/down arrow keys: Increase/decrease colour map index offset.
  b. Tilde: Enter face type number for filtering.
    b1. Number keys: Enter face type number.
    b2. Enter key: Submit new face type number.
        If pressed without entering a number, resets filter to show all types.
    b3. Tilde: Exit without changing face type.
  c. E key: Export mesh in Wavefront OBJ format. Set MESH_EXPORT_PREFIX, below, as desired.
*/

import java.util.Arrays;
import java.util.Map;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.HashSet;

// BEGIN values to set ==============================================================

final String PATH_BASE_SIMCOPTER = "C:/Maxis/SimCopter/";
final String PATH_BASE_STREETS = "C:/Maxis/Streets/";

final String PATH_TEXTURE_FILE_SIM3D = PATH_BASE_SIMCOPTER + "bmp/sim3d.bmp";
//final String PATH_TEXTURE_FILE_SIM3D = PATH_BASE_STREETS + "BMP/SIM3D.BMP";

final String PATH_TEXTURE_FILE_SKY = PATH_BASE_SIMCOPTER + "bmp/sky.bmp";
//final String PATH_TEXTURE_FILE_SKY = PATH_BASE_STREETS + "BMP/SKY.BMP";

final String PATH_MESH_FILE = PATH_BASE_SIMCOPTER + "geo/sim3d1.max";
//final String PATH_MESH_FILE = PATH_BASE_STREETS + "GEO/SIM3D1.MAX";

// I recommend setting this to 3d1, 3d2, 3d3, etc. based on which mesh file the mesh is coming from.
final String MESH_EXPORT_PREFIX = "Maxis";

// END values to set ================================================================

boolean drawLinesAndVertices = true; // Toggled using V key.
boolean showGizmo = true; // Toggled using G key.
boolean rotateCameraAroundMeshOrigin = true; // Otherwise around world origin (0, 0, 0); toggled using O key.

boolean printFaceDetails = false;
boolean useAlphaBlending = true;

final int WINDOW_SIZE = 800;
final int STROKE_WEIGHT_WIREFRAME_LINES = 4;
final int STROKE_WEIGHT_POINTS = 8; // Use for single-face points like lights.
final color COLOR_WIREFRAME = color(255, 0, 255);
final color COLOR_ORIGIN_VERTEX = color(255, 0, 0);

byte[] bytesMeshFile;

int[] meshTableStarts;
int curIndex = 0;

Mesh mesh = new Mesh();

float cameraYaw = 0;
float cameraPitch = 0;
float cameraRadius = 200;

boolean gettingFaceTypeFilter = false;
final int SHOW_ALL_FACES = -1;
int faceTypeFilter = SHOW_ALL_FACES;
String faceTypeString = "";

int colourIndexOffset = 0;

void settings() {
  size(WINDOW_SIZE, WINDOW_SIZE, P3D);
}

void setup() {
  bytesMeshFile = loadBytes(PATH_MESH_FILE);

  loadPalette(bytesMeshFile, palette);

  // GEOM table stuff
  int geomStart = bytesToInt32(getByteRange(bytesMeshFile, 24, 4));
  int subBlockCount = bytesToInt32(getByteRange(bytesMeshFile, geomStart + 8, 4));
  int nameTableStart = bytesToInt32(getByteRange(bytesMeshFile, geomStart + 16, 4));

  meshTableStarts = new int[subBlockCount];

  for (int i = 0; i < subBlockCount; ++i) {
    String curName = bytesToString(getByteRange(bytesMeshFile, nameTableStart + i*53, 17));
    int curMeshStart = bytesToInt32(getByteRange(bytesMeshFile, nameTableStart + i*53 + 17, 4));
    println("Name " + i + ": " + curName + " (" + curMeshStart + ")");
    meshTableStarts[i] = curMeshStart;
  }

  curIndex = 0;
  mesh.loadMesh(bytesMeshFile, meshTableStarts, curIndex);

  // Nearest-neighbour texture sampling.
  // See https://github.com/processing/processing/wiki/Advanced-OpenGL and https://github.com/processing/processing/issues/1272
  hint(DISABLE_TEXTURE_MIPMAPS);
  ((PGraphicsOpenGL)g).textureSampling(2);

  textureWrap(REPEAT);
}

void draw() {
  background(0, 128, 255);
  strokeWeight(STROKE_WEIGHT_WIREFRAME_LINES);
  textureMode(NORMAL);
  noStroke();

  mesh.drawMesh();

  // Axes
  if (showGizmo) {
    float AXIS_GIZMO_LENGTH = 8;
    float AXIS_GIZMO_THICKNESS = 1;

    noStroke();

    fill(255, 0, 0);
    pushMatrix();
    translate(AXIS_GIZMO_LENGTH/2f, 0, 0);
    box(AXIS_GIZMO_LENGTH, AXIS_GIZMO_THICKNESS, AXIS_GIZMO_THICKNESS);
    popMatrix();

    fill(0, 255, 0);
    pushMatrix();
    translate(0, AXIS_GIZMO_LENGTH/2f, 0);
    box(AXIS_GIZMO_THICKNESS, AXIS_GIZMO_LENGTH, AXIS_GIZMO_THICKNESS);
    popMatrix();

    fill(0, 0, 255);
    pushMatrix();
    translate(0, 0, AXIS_GIZMO_LENGTH/2f);
    box(AXIS_GIZMO_THICKNESS, AXIS_GIZMO_THICKNESS, AXIS_GIZMO_LENGTH);
    popMatrix();
  }

  // Camera

  float deltaX;
  float deltaY;

  if (mousePressed) {
    deltaX = mouseX - pmouseX;
    deltaY = mouseY - pmouseY;
  } else {
    deltaX = 0;
    deltaY = 0;
  }

  // https://processing.org/reference/camera_.html

  float targetX;
  float targetY;
  float targetZ;

  if (rotateCameraAroundMeshOrigin) {
    Vertex origin = mesh.getOrigin();
    targetX = origin.x;
    targetY = origin.y;
    targetZ = origin.z;
  } else {
    targetX = 0;
    targetY = 0;
    targetZ = 0;
  }

  float camPosX = targetX + cameraRadius*cos(radians(cameraYaw))*cos(radians(cameraPitch));
  float camPosY = targetY + cameraRadius*sin(radians(cameraPitch));
  float camPosZ = targetZ + cameraRadius*sin(radians(cameraYaw))*cos(radians(cameraPitch));

  final PVector camUp = new PVector(0, -1, 0); // (0, 1, 0) seems more appropriate, but gives inverted control. Don't recall why.
  camera(camPosX, camPosY, camPosZ, targetX, targetY, targetZ, camUp.x, camUp.y, camUp.z);

  cameraYaw -= deltaX;
  cameraPitch += deltaY;

  cameraPitch = max(min(cameraPitch, 89), -89);

  // Default settings are described here: https://processing.org/reference/perspective_.html
  perspective(PI/3f, (float) width/ (float) height, 1f, 1000f);
}

void mouseWheel(MouseEvent event) {
  cameraRadius += 0.1*abs(cameraRadius)*event.getCount();
}

void keyPressed() {

  if (keyCode == 39) { // Right arrow
    curIndex = (curIndex + 1) % meshTableStarts.length;
    mesh.loadMesh(bytesMeshFile, meshTableStarts, curIndex);
  } else if (keyCode == 37) { // Left arrow
    --curIndex;
    if (curIndex < 0) {
      curIndex = meshTableStarts.length - 1;
    }
    mesh.loadMesh(bytesMeshFile, meshTableStarts, curIndex);
  }

  // 48-57: number keys
  if (gettingFaceTypeFilter && keyCode >= 48 && keyCode <= 57) {
    faceTypeString = faceTypeString + key;
  }

  if (gettingFaceTypeFilter && keyCode == 10) { // 10 is enter
    gettingFaceTypeFilter = false;
    if (faceTypeString.equals("")) {
      faceTypeFilter = SHOW_ALL_FACES;
    } else {
      faceTypeFilter = Integer.parseInt(faceTypeString);
    }
    faceTypeString = "";
    println("Got face type number " + faceTypeFilter + ".");
  }

  if (keyCode == 38) { // Up arrow
    ++colourIndexOffset;
    println("Colour index offset: " + colourIndexOffset);
  } else if (keyCode == 40) { // Down arrow
    --colourIndexOffset;
    println("Colour index offset: " + colourIndexOffset);
  }

  if (key == 'o') {
    rotateCameraAroundMeshOrigin = !rotateCameraAroundMeshOrigin;
    if (rotateCameraAroundMeshOrigin) {
      println("Camera centre of rotation set to mesh origin");
    } else {
      println("Camera centre of rotation set to world origin (0, 0, 0)");
    }
  }

  if (key == '`') {
    if (!gettingFaceTypeFilter) {
      gettingFaceTypeFilter = true;
      println("Enter face type number. (ENTER to submit, TILDE to cancel.)");
    } else {
      gettingFaceTypeFilter = false;
      faceTypeString = "";
      println("Cancelled face type number input.");
    }
  }

  if (key == 'v') {
    drawLinesAndVertices = !drawLinesAndVertices;
  }

  if (key == 'e') {
    // Export current mesh.
    exportMesh(mesh);
  }

  if (key == 'g') {
    showGizmo = !showGizmo;
  }
}
