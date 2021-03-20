class Face {

  public int vertexCount;
  public int[] vertexIndices;
  public float[] u;
  public float[] v;
  public int texNum;
  public int texFile;
  public int flags;
  public int faceType;
  public int isLight;

  Face(int vertexCount, int[] vertexIndices, float[] u, float[] v, int texNum, int texFile, int flags, int faceType, int isLight) {
    this.vertexCount = vertexCount;
    this.vertexIndices = vertexIndices;
    this.u = u;
    this.v = v;
    this.texNum = texNum;
    this.texFile = texFile;
    this.flags = flags;
    this.faceType = faceType;
    this.isLight = isLight;
  }
}
