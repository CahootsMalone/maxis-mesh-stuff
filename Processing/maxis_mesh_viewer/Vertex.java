/*
Regarding the vertex scale factor specified below, see:
https://github.com/CahootsMalone/maxis-mesh-stuff/blob/master/Info/Maxis-Mesh-Format.md#scale

Additional notes:

Generic one-tile road pieces are (+/-2097151, 0, +/-2097151)
Exact value varies slightly: sometimes 2097152, [...]53, [...]54, etc.

Accordingly, roads have a side length of 4,194,302 units (give or take).
This is where the value quoted in the document linked above comes from.
*/

class Vertex {
  
  private static final float VERTEX_SCALE_FACTOR = 262144.0f; // See block comment above.

  public float x;
  public float y;
  public float z;

  Vertex(float x, float y, float z) {
    this.x = x/VERTEX_SCALE_FACTOR;
    this.y = y/VERTEX_SCALE_FACTOR;
    this.z = z/VERTEX_SCALE_FACTOR;
  }

  public String toString() {
    return "(" + x*VERTEX_SCALE_FACTOR + ", " + y*VERTEX_SCALE_FACTOR + ", " + z*VERTEX_SCALE_FACTOR + ")";
  }
}
