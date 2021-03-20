final int PALETTE_SIZE = 256;
final String FALLBACK_TEXTURE_FILE_NAME = "fallback-checkerboard.png";

color palette[] = new color[PALETTE_SIZE];

boolean areTexturesLoaded = false;

HashMap<String, PImage> textureMap = new HashMap<String, PImage>();

TextureSet textureSetSim3d;
TextureSet textureSetSky;

void loadPalette(byte bytes[], color[] target) {
  byte paletteBytes[] = getByteRange(bytes, 61, 768);

  for (int i = 0; i < PALETTE_SIZE; ++i) {
    int r = byteToUInt8(paletteBytes[3*i]);
    int g = byteToUInt8(paletteBytes[3*i + 1]);
    int b = byteToUInt8(paletteBytes[3*i + 2]);
    target[i] = color(r, g, b);
  }
}

void loadTextures() {
  textureSetSim3d = new TextureSet(PATH_TEXTURE_FILE_SIM3D);
  textureSetSky = new TextureSet(PATH_TEXTURE_FILE_SKY);
}

static String generateTextureKey(int texFile, int texNum) {
  return texFile + "-" + texNum;
}

void checkLoadTexture(int texFile, int texNum) {

  if (!areTexturesLoaded) {
    loadTextures();
    areTexturesLoaded = true;
  }

  String texKey = generateTextureKey(texFile, texNum);
  if (!textureMap.containsKey(texKey)) {
    println("Loading texture " + texKey);

    PImage texture;

    if (texFile == 0) { // Dedicated texture
      texture = textureSetSim3d.getTexture(texNum, palette);

      if (texture == null) {
        texture = loadImage(FALLBACK_TEXTURE_FILE_NAME);
      }
    } else { // Texture within a texture atlas
      
      if (texFile == 20) { // Oddly, this means the texture at index 4 in sky.bmp, not the one at index 20 in sim3d.bmp.
        texture = textureSetSky.getTexture(4, palette);
      }
      else {
        texture = textureSetSim3d.getTexture(texFile, palette);
      }

      if (texture == null) {
        texture = loadImage(FALLBACK_TEXTURE_FILE_NAME);
      }

      int row = floor(texNum/8);
      int col = texNum % 8;

      // Col 0 is left, row 0 is bottom.
      texture = texture.get(col*32, (7 - row)*32, 32, 32);
    }

    textureMap.put(texKey, texture);
  }
}
