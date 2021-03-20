/*
Meshes are exported in Wavefront OBJ format.
  http://paulbourke.net/dataformats/obj/
  http://paulbourke.net/dataformats/mtl/
  https://en.wikipedia.org/wiki/Wavefront_.obj_file
OBJ files use a right-handed coordinate system.
*/

final String MESH_EXPORT_FOLDER_NAME = "exported-meshes";

void exportMesh(Mesh mesh) {
  println("Exporting mesh...");
  
  String name = MESH_EXPORT_PREFIX + "-mesh-" + curIndex;

  List<String> data = new ArrayList<String>();

  data.add("mtllib " + name + ".mtl");

  data.add("s off");
  
  Vertex[] vertices = mesh.vertices;
  Face[] faces = mesh.faces;

  for (int i = 0; i < vertices.length; ++i) {
    // Negate Z since OBJ files are right-handed.
    String curVer = "v " + (vertices[i].x) + " " + vertices[i].y + " " + (-1*vertices[i].z);
    data.add(curVer);
  }
  
  List<String> dataMaterials = new ArrayList<String>();
  Set<String> exportedMaterialNames = new HashSet<String>();

  for (int faceIndex = 0; faceIndex < faces.length; ++faceIndex) {
    
    Boolean useTexture = faces[faceIndex].faceType == 13 || faces[faceIndex].faceType == 18 || faces[faceIndex].faceType == 2;
    
    if (useTexture) {

      String textureKey = generateTextureKey(faces[faceIndex].texFile, faces[faceIndex].texNum);
      String materialName = generateMaterialName(textureKey);
      
      if (!exportedMaterialNames.contains(materialName)){
        checkExportTexture(textureKey);
        addMaterialTextured(dataMaterials, textureKey);
        exportedMaterialNames.add(materialName);
      }

      data.add("usemtl " + materialName);
    } else {
      // Unfortunately this isn't really representative of how meshes look in-game.
      // Faces are assigned a colour within a gradient (most of the time)
      // and then all the colours in the gradient are used in-game.
      // There's no way to represent that in the exported mesh.
      int colourIndex = faces[faceIndex].texNum;
      String nameBase = "colour-" + colourIndex;
      String materialName = generateMaterialName(nameBase);
      
      if (!exportedMaterialNames.contains(materialName)){
        color colour = palette[colourIndex];
        
        addMaterialColour(dataMaterials, nameBase, (int) red(colour), (int) green(colour), (int) blue(colour));
        exportedMaterialNames.add(materialName);
      }
      
      data.add("usemtl " + materialName);
    }

    int vCount = faces[faceIndex].vertexCount;

    // Add lines for this face's UV coordinates.
    for (int v = 0; v < vCount; ++v) {
      // Negate Z since OBJ files are right-handed. TODO check (against the game) that this actually works consistently.
      String curTexVer = "vt " + faces[faceIndex].u[v] + " " + (-1*faces[faceIndex].v[v]);
      data.add(curTexVer);
    }    

    // Add line for face.

    String curFace = "f";

    for (int v = 0; v < vCount; ++v) {
      // Reverse winding order (SimCopter/Streets use LHR, OBJ uses RHR)
      curFace += " " + (faces[faceIndex].vertexIndices[vCount - 1 - v] + 1) + "/" + (-1*(v + 1));
    }
    data.add(curFace);
  }
  
  String filename = MESH_EXPORT_FOLDER_NAME + "/" + name + ".obj";
  String[] dataArray = new String[data.size()];
  data.toArray(dataArray);
  saveStrings(filename, dataArray);
  
  String filenameMatLib = MESH_EXPORT_FOLDER_NAME + "/" + name + ".mtl";
  String[] dataMaterialsArray = new String[dataMaterials.size()];
  dataMaterials.toArray(dataMaterialsArray);
  saveStrings(filenameMatLib, dataMaterialsArray);

  println("Export complete.");
}

void checkExportTexture(String textureKey) {
  String filename = MESH_EXPORT_FOLDER_NAME + "/tex" + textureKey + ".png";
  if (textureMap.containsKey(textureKey)) {

    File f = new File(filename);
    if (!f.isFile()) { // TODO BUG isFile() is always false because file name doesn't include the program directory.
      PImage texture = textureMap.get(textureKey);
      texture.save(filename);
    } else {
      println("WARNING: tried to export texture, but file already exists. Key was " + textureKey);
    }
  } else {
    println("ERROR: tried to export texture that doesn't exist. Key was " + textureKey);
  }
}

static String generateMaterialName(String name) {
  return "mat" + name;
}

static void addMaterialTextured(List<String> dataMaterials, String textureKey) {
  dataMaterials.add("newmtl " + generateMaterialName(textureKey));
  dataMaterials.add("Ka 1.0 1.0 1.0");
  dataMaterials.add("Kd 1.0 1.0 1.0");
  dataMaterials.add("Ks 0.0 0.0 0.0");
  dataMaterials.add("Ns 0.0");
  dataMaterials.add("map_Ka tex" + textureKey + ".png");
  dataMaterials.add("map_Kd tex" + textureKey + ".png");
  dataMaterials.add("");
}

static void addMaterialColour(List<String> dataMaterials, String name, int r, int g, int b) {
  dataMaterials.add("newmtl " + generateMaterialName(name));
  dataMaterials.add("Ka " + r/255.0 + " " + g/255.0 + " " + b/255.0);
  dataMaterials.add("Kd " + r/255.0 + " " + g/255.0 + " " + b/255.0);
  dataMaterials.add("Ks 0.0 0.0 0.0");
  dataMaterials.add("Ns 0.0");
  dataMaterials.add("");
}
