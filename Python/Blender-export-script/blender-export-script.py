# Blender-to-Maxis-mesh export script
# Author: Cahoots Malone

# ==========================
# === BEGIN INSTRUCTIONS ===
# ==========================

# In Blender, go to the Scripting tab, create a new script, and paste the contents of this file into it. Run the script to export the model.

# Set the parameters in the PARAMETERS section below before exporting.

# Ensure any changes to rotation or scale made in object mode are applied (Ctrl+A) before exporting.

# For simplicity, this script only exports the first object in the scene.

# Treat the positive Y axis as forward and the positive Z axis as up.

# --- COLOURS ---

# Use vertex paint mode to assign colours. Use only colours that appear in the game's palette.
# To export a palette, use the Maxis Texture Tool (https://github.com/CahootsMalone/maxis-texture-tool/releases).

# --- VERTEX GROUPS ---

# Light group:
# Faces that represent light beams (e.g., from car headlights or street lights) should have their vertices assigned to a group named "light".
# These faces will be assigned special flag values.
# Use the colours at indices [43,55] in the palette; SimCopter remaps this range to a grey gradient near the end of the palette.
# Car headlights use four faces set to the colours at indices 43, 53, 54, and 55 (from nearest the car to furthest away from it).

# Unshaded group:
# The last 10 palette colours aren't part of a gradient and don't get brighter/darker depending on orientation.
# To limit colour index selection for a face to the last 10 colours in the palette (indices [246,255]), assign its vertices to a group named "unshaded".

# --- LIMITATIONS ---

# There are many limitations to this script (very limited support for different types of faces, no texture mapping, etc.).
# If there's sufficient interest I may expand it, but I suspect modding SimCopter and Streets of SimCity is of rather limited appeal!

# ========================
# === END INSTRUCTIONS ===
# ========================

import bpy

# ========================
# === BEGIN PARAMETERS ===
# ========================

# This should point to a palette in GIMP palette format exported by the Maxis Texture Tool (https://github.com/CahootsMalone/maxis-texture-tool/releases).
palettePath = '[...]/palette.gpl'

outPath = '[...]/out.bin'

# Bytes (max value 255) that affect collision detection.
# Unclear how they're used. They don't specify the dimensions of the collision volume (at least not directly).
# (0,0,0) gives no collision.
# (0,0,250) adds a large, offset collision volume.
# Most combinations (e.g., 50,50,50) result in a small collision volume.
col1 = 50
col2 = 50
col3 = 50

# Coordinates of origin in Blender units.
# It's unclear how/if the origin is used.
originX = 0
originY = 0
originZ = 0

# ======================
# === END PARAMETERS ===
# ======================

def write_vertex(file, x, y, z):
    # Blender: +Z = up, RHR.
    # SC: +X = right, +Y = up, +Z = forward, LHR.
    file.write(round(CONST_SCALE_FACTOR*x).to_bytes(4, byteorder='little', signed=True))
    file.write(round(CONST_SCALE_FACTOR*z).to_bytes(4, byteorder='little', signed=True))
    file.write(round(CONST_SCALE_FACTOR*y).to_bytes(4, byteorder='little', signed=True))

# At this scale factor, a car wheel is about 2.3 Blender units in diameter (i.e., 230,000 SimCopter units).
CONST_SCALE_FACTOR = 100000

palette = []
with open(palettePath, 'r') as pf:
    lines = pf.readlines()
    for i in range(3, len(lines)):
        palette.append([int(c) for c in lines[i].split()])

theMesh = bpy.data.objects[0].data

vertexCount = len(theMesh.vertices) + 1 # Add one for origin.
faceCount = len(theMesh.polygons)

with open(outPath, 'wb') as file:
    
    # Object header
    
    file.write(b'OBJX')
    file.write(b'DEAD') # Size-12, updated below.
    file.write(vertexCount.to_bytes(2, byteorder='little'))
    file.write(faceCount.to_bytes(2, byteorder='little'))
    file.write((0).to_bytes(4, byteorder='little')) # Always zero.
    
    file.write(col1.to_bytes(1, byteorder='little'))
    file.write(col2.to_bytes(1, byteorder='little'))
    file.write(col3.to_bytes(1, byteorder='little'))
    file.write((0).to_bytes(1, byteorder='little')) # Almost always zero (in SimCopter, 4 of the 400 meshes have it set to 1 instead).
    
    file.write((0).to_bytes(4, byteorder='little')) # Always zero.
    nameBytes = bytearray(b'Wienermobile\0')
    nameBytes.extend((88-len(nameBytes))*[0])
    file.write(nameBytes)    
    file.write(b'DEADDEADDEAD') # Mystery 12-byte sequence; must be replaced on import with the 12-byte sequence of the mesh being replaced.

    # Vertices
    write_vertex(file, originX, originY, originZ) # Origin (always the first vertex).
    for vertex in theMesh.vertices:
        # Note that these coordinates are expressed in the object's local coordinate system.
        write_vertex(file, vertex.co.x, vertex.co.y, vertex.co.z)
    
    # Faces
    for face in theMesh.polygons:
        
        # SimCopter's winding order is opposite Blender's.
        # This is a little fiddly to manage with the coordinate swapping.
        vertices = list(reversed(face.vertices))
        
        fVertexCount = len(face.vertices)
        fSizeBytes = 4+4+2+2+2+4+3+fVertexCount*2+fVertexCount*8
        flagValue = 3
        isLight = 0
        texFile = 0
        mysteryByte = 15; # This matters, if it's not compatible with the flag value the game crashes when the mesh is spawned.
        
        paletteSearchStartIndex = 0
        
        # Check if first vertex in this face belongs to a group.
        indexFirstVertex = vertices[0]
        if (len(theMesh.vertices[indexFirstVertex].groups) > 0):
            for curGroup in theMesh.vertices[indexFirstVertex].groups:
                if (bpy.data.objects[0].vertex_groups[curGroup.group].name == 'light'):
                    flagValue = 2
                    mysteryByte = 11
                elif (bpy.data.objects[0].vertex_groups[curGroup.group].name == 'unshaded'):
                    paletteSearchStartIndex = 246
        
        # If colour isn't in the palette, this just crashes rather than trying to find the nearest match.
        color = theMesh.vertex_colors[0].data[face.loop_indices[0]].color[0:3]
        color = [round(255*c) for c in color]
        colorIndex = paletteSearchStartIndex + palette[paletteSearchStartIndex:].index(color)
        
        file.write(b'FACE')
        file.write(fSizeBytes.to_bytes(4, byteorder='little'))
        file.write(fVertexCount.to_bytes(2, byteorder='little'))
        file.write(flagValue.to_bytes(2, byteorder='little'))
        file.write(isLight.to_bytes(2, byteorder='little'))
        file.write(colorIndex.to_bytes(4, byteorder='little')) # Group
        file.write(mysteryByte.to_bytes(1, byteorder='little')) # Mystery byte
        file.write(colorIndex.to_bytes(1, byteorder='little')) # Color
        file.write(texFile.to_bytes(1, byteorder='little'))
        
        for vertIndex in vertices:
            # Add one to index since first vertex in table is origin.
            file.write((vertIndex+1).to_bytes(2, byteorder='little'))
        
        # Textures coordinates
        for vertIndex in face.vertices:
            file.write((0).to_bytes(4, byteorder='little', signed=True))
            file.write((0).to_bytes(4, byteorder='little', signed=True))
    
    # Set size
    fileSize = file.tell() - 12 # Subtract 12 for mysterious 12-byte sequence that isn't counted.
    file.seek(4, 0)
    file.write(fileSize.to_bytes(4, byteorder='little'))
    