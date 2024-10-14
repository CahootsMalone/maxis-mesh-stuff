class Mesh {

  private Vertex[] vertices;
  private Face[] faces;
  private float collisionRadius; // Might be a rendering radius as well?

  public void loadMesh(byte[] bytesMeshFile, int[] meshStartOffsets, int index) {
    int meshTableStart = meshStartOffsets[index];

    println("================================");
    println("Loading mesh " + index + " at " + meshTableStart);

    int vertexCount = bytesToInt16(getByteRange(bytesMeshFile, meshTableStart + 8, 2));
    int faceCount = bytesToInt16(getByteRange(bytesMeshFile, meshTableStart + 10, 2));

    String name = bytesToString(getByteRange(bytesMeshFile, meshTableStart + 24, 88));

    println("Mesh name: " + name);

    println("Mesh has " + vertexCount +  " vertices and " + faceCount + " faces.");

    // Breaking up non-zero unknown four-byte value (as a 32-bit int, it's a huge value, hinting that it's meant to be interpreted some other way)
    // See https://github.com/CahootsMalone/maxis-mesh-stuff/blob/master/Info/Collision%20notes.md
    int mystery1 = byteToUInt8(bytesMeshFile[meshTableStart + 16]);
    int mystery2 = byteToUInt8(bytesMeshFile[meshTableStart + 17]);
    int mystery3 = byteToUInt8(bytesMeshFile[meshTableStart + 18]);
    int mystery4 = byteToUInt8(bytesMeshFile[meshTableStart + 19]);

    println("Collision bytes? " + mystery1 + " " + mystery2 + " " + mystery3 + " " + mystery4);
    
    // Should actually be a UInt32, but no values are large enough for sign confusion so I just used the existing int32 method.
    // Scale factor should be the same as VERTEX_SCALE_FACTOR in Vertex class (just hardcoded again here to save time).
    collisionRadius = bytesToInt32(getByteRange(bytesMeshFile, meshTableStart + 16, 4)) / 262144.0;
    println("Collision radius: " + collisionRadius);

    int vertexStart = meshTableStart + 124;
    int faceStart = vertexStart + (vertexCount*12);

    vertices = new Vertex[vertexCount];
    faces = new Face[faceCount];

    for (int vertexIndex = 0; vertexIndex < vertexCount; ++vertexIndex) {
      int curStart = vertexStart + vertexIndex*12;

      int x = bytesToInt32(new byte[]{bytesMeshFile[curStart], bytesMeshFile[curStart+1], bytesMeshFile[curStart+2], bytesMeshFile[curStart+3]});
      int y = bytesToInt32(new byte[]{bytesMeshFile[curStart+4], bytesMeshFile[curStart+5], bytesMeshFile[curStart+6], bytesMeshFile[curStart+7]});
      int z = bytesToInt32(new byte[]{bytesMeshFile[curStart+8], bytesMeshFile[curStart+9], bytesMeshFile[curStart+10], bytesMeshFile[curStart+11]});

      vertices[vertexIndex] = new Vertex(x, y, z);

      if (vertexIndex == 0) {
        println("Origin: " + vertices[0].toString());
      }
    }

    int curFace = faceStart;

    // Add 21 + N*2 + N*4*2 to get next start.
    // Or just take first int32 after header (size).
    for (int faceIndex = 0; faceIndex < faceCount; ++faceIndex) {
      int nextFace = curFace + bytesToInt32(getByteRange(bytesMeshFile, curFace + 4, 4));
      int faceVertexCount = bytesToInt16(getByteRange(bytesMeshFile, curFace + 8, 2)); 

      int[] vIndices = new int[faceVertexCount];
      for (int v = 0; v < faceVertexCount; ++v) {
        int vIndex = bytesToInt16(getByteRange(bytesMeshFile, curFace + 21 + v*2, 2));
        vIndices[v] = vIndex;
      }

      // Get UVs
      float[] u = new float[faceVertexCount];
      float[] v = new float[faceVertexCount];
      int uvStart = curFace + 21 + faceVertexCount*2;
      for (int j = 0; j < faceVertexCount; ++j) {
        int uInt = bytesToInt32(getByteRange(bytesMeshFile, uvStart + j*8 + 0, 4));
        int vInt = bytesToInt32(getByteRange(bytesMeshFile, uvStart + j*8 + 4, 4));

        u[j] = ((1.0*uInt)/65536);
        v[j] = 1 - ((1.0*vInt)/65536); // Processing has UV origin in top-left, not bottom-left as is typical.
      }

      int flags = bytesToInt16(getByteRange(bytesMeshFile, curFace + 4 + 4 + 2, 2));
      int isLight = bytesToInt16(getByteRange(bytesMeshFile, curFace + 4 + 4 + 2 + 2, 2));
      int group = bytesToInt32(getByteRange(bytesMeshFile, curFace + 4 + 4 + 2 + 2 + 2, 4));

      int faceType = byteToUInt8(bytesMeshFile[curFace + 4 + 4 + 2 + 2 + 2 + 4]);

      int texNum = byteToUInt8(bytesMeshFile[curFace + 4 + 4 + 2 + 2 + 2 + 4 + 1]);
      int texFile = byteToUInt8(bytesMeshFile[curFace + 4 + 4 + 2 + 2 + 2 + 4 + 2]);

      if (printFaceDetails) {
        println("Face " + faceIndex + " | texNum = " + texNum + " | texFile = " + texFile + " | faceType = " + faceType + " | flags? = " + flags + " | isLight = " + isLight + " | group = " + group + " | vertexCount = " + faceVertexCount);
      }

      faces[faceIndex] = new Face(faceVertexCount, vIndices, u, v, texNum, texFile, flags, faceType, isLight);

      curFace = nextFace;
    }
  }

  public void drawMesh() {
    if (drawLinesAndVertices) {
      for (int i = 0; i < vertices.length; ++i) {
        if (i == 0) {
          stroke(COLOR_ORIGIN_VERTEX);
        } else {
          stroke(COLOR_WIREFRAME);
        }
        point(vertices[i].x, vertices[i].y, vertices[i].z);
      }
    }

    PImage textureToUse = null;
    boolean useTexture = true;

    for (int faceIndex = 0; faceIndex < faces.length; ++faceIndex) {

      // Only display certain types of faces.
      if (faceTypeFilter != -1) {
        if (faces[faceIndex].faceType != faceTypeFilter) {
          continue;
        }
      }

      boolean isTranslucent = faces[faceIndex].faceType == 11;

      useTexture = faces[faceIndex].faceType == 13 || faces[faceIndex].faceType == 18 || faces[faceIndex].faceType == 2;

      int curTexNum = faces[faceIndex].texNum;
      int curTexFile = faces[faceIndex].texFile;

      if (useTexture) {
        checkLoadTexture(curTexFile, curTexNum);
        textureToUse = textureMap.get(generateTextureKey(curTexFile, curTexNum));
        fill(255, 255, 255);
      } else {

        int paletteIndex = curTexNum + colourIndexOffset;
        paletteIndex = max(min(paletteIndex, 255), 0);

        if (isTranslucent && useAlphaBlending) {
          // Processing's alpha blending is inconsistent; frequently, objects behind a translucent face aren't visible
          fill(palette[paletteIndex], 128);
        } else {
          fill(palette[paletteIndex]);
        }
      }

      if (faces[faceIndex].vertexCount == 1) {
        strokeWeight(STROKE_WEIGHT_POINTS);
        stroke(palette[curTexNum]);
        point(vertices[faces[faceIndex].vertexIndices[0]].x, vertices[faces[faceIndex].vertexIndices[0]].y, vertices[faces[faceIndex].vertexIndices[0]].z);

        strokeWeight(STROKE_WEIGHT_WIREFRAME_LINES);
        stroke(COLOR_WIREFRAME);
        if (!drawLinesAndVertices) {
          noStroke();
        }
      }
      if (faces[faceIndex].vertexCount == 2) {

        if (faces[faceIndex].faceType == 2) { // Line corresponding to a sprite
          // Vertex specifying bottom middle isn't part of line; appears in vertex list after first vertex in ine.
          int extraIndex = faces[faceIndex].vertexIndices[0] + 1;

          float yBottom = vertices[extraIndex].y;
          float yTop = vertices[faces[faceIndex].vertexIndices[1]].y;

          PVector bottom = new PVector(vertices[extraIndex].x, vertices[extraIndex].y, vertices[extraIndex].z);
          PVector sideProjectedDown = new PVector(vertices[faces[faceIndex].vertexIndices[0]].x, yBottom, vertices[faces[faceIndex].vertexIndices[0]].z);
          PVector bottomCentreToSide = PVector.sub(sideProjectedDown, bottom);

          PVector bottom1 = PVector.add(bottom, bottomCentreToSide);
          PVector bottom2 = PVector.sub(bottom, bottomCentreToSide);
          PVector top1 = bottom1.copy();
          top1.y = yTop;
          PVector top2 = bottom2.copy();
          top2.y = yTop;

          beginShape(QUADS);

          if (useTexture) {
            texture(textureToUse);
          }

          // Processing's UV origin is top-left, not bottom-left as is typical.
          // However, sprite textures are flipped vertically compared to other textures.
          vertex(bottom1.x, bottom1.y, bottom1.z, 0.0, 0.0);
          vertex(bottom2.x, bottom2.y, bottom2.z, 1.0, 0.0);
          vertex(top2.x, top2.y, top2.z, 1.0, 1.0);
          vertex(top1.x, top1.y, top1.z, 0.0, 1.0);
          endShape();
        } else {
          strokeWeight(1);
          stroke(palette[curTexNum]);
          line(
            vertices[faces[faceIndex].vertexIndices[0]].x, 
            vertices[faces[faceIndex].vertexIndices[0]].y, 
            vertices[faces[faceIndex].vertexIndices[0]].z, 
            vertices[faces[faceIndex].vertexIndices[1]].x, 
            vertices[faces[faceIndex].vertexIndices[1]].y, 
            vertices[faces[faceIndex].vertexIndices[1]].z);

          strokeWeight(STROKE_WEIGHT_WIREFRAME_LINES);
          stroke(COLOR_WIREFRAME);
          if (!drawLinesAndVertices) {
            noStroke();
          }
        }
      } else if (faces[faceIndex].vertexCount == 3) {
        beginShape(TRIANGLES);

        if (useTexture) {
          texture(textureToUse);
        }

        vertex(vertices[faces[faceIndex].vertexIndices[0]].x, vertices[faces[faceIndex].vertexIndices[0]].y, vertices[faces[faceIndex].vertexIndices[0]].z, faces[faceIndex].u[0], faces[faceIndex].v[0]);
        vertex(vertices[faces[faceIndex].vertexIndices[1]].x, vertices[faces[faceIndex].vertexIndices[1]].y, vertices[faces[faceIndex].vertexIndices[1]].z, faces[faceIndex].u[1], faces[faceIndex].v[1]);
        vertex(vertices[faces[faceIndex].vertexIndices[2]].x, vertices[faces[faceIndex].vertexIndices[2]].y, vertices[faces[faceIndex].vertexIndices[2]].z, faces[faceIndex].u[2], faces[faceIndex].v[2]);
        endShape();
      } else if (faces[faceIndex].vertexCount == 4) {
        beginShape(QUADS);

        if (useTexture) {
          texture(textureToUse);
        }

        vertex(vertices[faces[faceIndex].vertexIndices[0]].x, vertices[faces[faceIndex].vertexIndices[0]].y, vertices[faces[faceIndex].vertexIndices[0]].z, faces[faceIndex].u[0], faces[faceIndex].v[0]);
        vertex(vertices[faces[faceIndex].vertexIndices[1]].x, vertices[faces[faceIndex].vertexIndices[1]].y, vertices[faces[faceIndex].vertexIndices[1]].z, faces[faceIndex].u[1], faces[faceIndex].v[1]);
        vertex(vertices[faces[faceIndex].vertexIndices[2]].x, vertices[faces[faceIndex].vertexIndices[2]].y, vertices[faces[faceIndex].vertexIndices[2]].z, faces[faceIndex].u[2], faces[faceIndex].v[2]);
        vertex(vertices[faces[faceIndex].vertexIndices[3]].x, vertices[faces[faceIndex].vertexIndices[3]].y, vertices[faces[faceIndex].vertexIndices[3]].z, faces[faceIndex].u[3], faces[faceIndex].v[3]);
        endShape();
      } else {

        int curFaceVertexCount = faces[faceIndex].vertexCount;

        beginShape();

        if (useTexture) {
          texture(textureToUse);
        }

        for (int v = 0; v < curFaceVertexCount; ++v) {
          vertex(vertices[faces[faceIndex].vertexIndices[v]].x, vertices[faces[faceIndex].vertexIndices[v]].y, vertices[faces[faceIndex].vertexIndices[v]].z, faces[faceIndex].u[v], faces[faceIndex].v[v]);
        }

        endShape();
      }
    }
    
    // Draw a circle for the object's radius.
    if (showRadiusCircle) {
      stroke(COLOR_COLLISION_RADIUS_CIRCLE);
      strokeWeight(STROKE_WEIGHT_WIREFRAME_LINES);
      
      float originX = vertices[0].x;
      float originZ = vertices[0].z;
      
      // Circle should be centred on origin (at least in the XZ plane).
      // If not, circle location is visibly incorrect for models with an origin not near (0,0,0).
      int circleSideCount = 16;
      float circleSegmentAngle = (2*PI)/circleSideCount;
      for (int i = 0; i < circleSideCount; ++i) {
         float angleStart = i*circleSegmentAngle;
         float angleEnd = (i+1)*circleSegmentAngle;
         
         float startX = collisionRadius * cos(angleStart);
         float startZ = collisionRadius * sin(angleStart);
         float endX = collisionRadius * cos(angleEnd);
         float endZ = collisionRadius * sin(angleEnd);
         line(originX + startX, 0, originZ + startZ, originX + endX, 0, originZ + endZ);
      }
    }
  }

  public Vertex getOrigin() {
    return vertices[0];
  }
}
