class TextureSet {
  private byte[] bytes;
  private int[] textureOffsets;

  TextureSet(String filePath) {
    bytes = loadBytes(filePath);

    //int fileSize = BytesToInt32(GetByteRange(bytes, 0, 4));
    int textureCount = bytesToInt32(getByteRange(bytes, 8, 4));
    int resolutionBlockCount = bytesToInt32(getByteRange(bytes, 12, 4));

    int textureBlockStart = 4*4 + resolutionBlockCount*3*4;

    textureOffsets = new int[textureCount];

    int curTexStart = textureBlockStart;
    for (int i = 0; i < textureCount; ++i) {
      textureOffsets[i] = curTexStart;

      int texWidth = bytesToInt32(getByteRange(bytes, curTexStart, 4));
      int texHeight = bytesToInt32(getByteRange(bytes, curTexStart + 4, 4));
      int indicesStart = curTexStart + 3*4 + texHeight*4;

      curTexStart = indicesStart + texWidth*texHeight*1;
    }
  }

  public PImage getTexture(int index, color[] palette) {
    if (index < 0 || index >= textureOffsets.length) {
      println("Texture index out of range.");
      return null;
    }

    int start = textureOffsets[index];

    int texWidth = bytesToInt32(getByteRange(bytes, start, 4));
    int texHeight = bytesToInt32(getByteRange(bytes, start + 4, 4));
    int indicesStart = start + 3*4 + texHeight*4;

    int pixelCount = texWidth*texHeight;

    PImage texture = new PImage(texWidth, texHeight);

    texture.loadPixels();

    for (int i = 0; i < pixelCount; ++i) {
      int pixelIndex = byteToUInt8(bytes[indicesStart + i]);

      // Processing starts in top-left, Maxis textures start in bottom-left.
      int row = texHeight-1 - i/texWidth; // From the top
      int col = i % texWidth;
      int procIndex = row*texWidth + col;

      texture.pixels[procIndex] = palette[pixelIndex];
    }

    texture.updatePixels();

    return texture;
  }
}
