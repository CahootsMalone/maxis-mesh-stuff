# Blender-to-Maxis-mesh export script
# Author: Cahoots Malone

# ==========================
# === BEGIN INSTRUCTIONS ===
# ==========================

# In Blender, go to the Scripting tab, create a new script, and paste the contents of this file into it.
# Select the object you wish to export and ensure Blender is in Object Mode.
# Set the parameters in the PARAMETERS section below before exporting.
# Run the script to export the model.

# Ensure any changes to rotation or scale made in object mode are applied (Ctrl+A) before exporting.

# For simplicity, this script only exports the currently-selected object.

# Treat the positive Y axis as forward and the positive Z axis as up.

# --- TEXTURE OR COLOUR ASSIGNMENT: VERTEX GROUPS AND SPECIAL GROUP NAMES ---

# The "specialGroups" dictionary (line 138) is used to specify textures or colours for vertex groups.
#   Key: name of vertex group
#   Value: anonymous dictionary with the following key/value pairs:
#       faceType: one of the FACE_TYPE_[...] strings defined below
#       texFile: texture file value (0 for dedicated textures or colours)
#       texIndex: texture index (colour index for untextured faces)

# Faces with a given set of attributes should not share vertices with faces possessing attributes that differ.
# Use Blender's "Split" operation (in Edit mode, select a face and press "Y") to disconnect faces.

# --- COLOURS ---

# Colours can also be assigned using vertex paint mode.

# Ensure painted vertices belong to a vertex group using one of the FACE_TYPE_[...] strings as its name.
#   The following face types use colours:
#       FACE_TYPE_FACE_TRANSLUCENT
#       FACE_TYPE_FACE_COLOR_FLAT_SHADED
#       FACE_TYPE_FACE_COLOR_SMOOTH_SHADED
#       FACE_TYPE_LINE_NORMAL
#       FACE_TYPE_POINT_LIGHT

# Use only colours that appear in the game's palette.
# The index will be chosen automatically, but may be incorrect if a colour appears multiple times in the palette.
# For best results, use a special group name instead (see above).

# To export a palette, use the Maxis Texture Tool (https://github.com/CahootsMalone/maxis-texture-tool/releases).

# --- OLD NOTES ---

# TODO add isLight to special group check.

# SimCopter-specific notes:
#   Light beams:
#       Faces that represent light beams (e.g., from car headlights or street lights) should have their vertices assigned to a vertex group named "faceTranslucent" or using a special group name with "faceType" set to FACE_TYPE_FACE_TRANSLUCENT.
#       Use the colours at indices [43,55] in the palette; SimCopter remaps this range to a grey gradient near the end of the palette.
#       Car headlights use four faces set to the colours at indices 43, 53, 54, and 55 (from nearest the car to furthest away from it).
#   Constant colours:
#       The last 10 palette colours aren't part of a gradient and don't get brighter/darker depending on orientation.
#       To limit colour index selection for a face to the last 10 colours in the palette (indices [246,255]), assign its vertices to a group named "unshaded" or use special groups to assign the colour indices explicitly.

# ========================
# === END INSTRUCTIONS ===
# ========================

import bpy

# ========================
# === BEGIN PARAMETERS ===
# ========================

# PLEASE NOTE: if desired, also add entries to the specialGroups dictionary below for texture assignment.

# This should point to a palette in GIMP palette format exported by the Maxis Texture Tool (https://github.com/CahootsMalone/maxis-texture-tool/releases).
palettePath = 'C:/[...]/palette.gpl'

outPath = 'C:/[...]/output-folder/'

# Bytes (max value 255) that affect collision detection.
# Unclear how they're used. They don't specify the dimensions of the collision volume (at least not directly).
col1 = 100
col2 = 100
col3 = 45 # Affects collision in an unclear way (0 = no collision)

# Coordinates of origin in Blender units.
# It's unclear how/if the origin is used.
originX = 0
originY = 0
originZ = 0

# ======================
# === END PARAMETERS ===
# ======================

# Based on rotor diameter; 16x16 metre tiles
# For details, see https://github.com/CahootsMalone/maxis-mesh-stuff/blob/master/Info/Maxis-Mesh-Format.md#scale
CONST_SCALE_FACTOR = 262144 # 2^18

CONST_UV_SCALE_FACTOR = 65536 # 2^16

FACE_TYPE_LINE_SPRITE = "lineSprite"
FACE_TYPE_FACE_TRANSLUCENT = "faceTranslucent"
FACE_TYPE_FACE_TEXTURED_DEDICATED = "faceTexturedDedicated"
FACE_TYPE_FACE_COLOR_FLAT_SHADED = "faceColorFlatShaded"
FACE_TYPE_FACE_TEXTURED_ATLAS = "faceTexturedAtlas"
FACE_TYPE_FACE_COLOR_SMOOTH_SHADED = "faceColorSmoothShaded"
FACE_TYPE_LINE_NORMAL = "lineNormal"
FACE_TYPE_POINT_LIGHT = "pointLight"
FACE_TYPE_POINT_EMITTER = "pointEmitter"

faceTypeNameToNumber = {
    FACE_TYPE_LINE_SPRITE: 2,
    FACE_TYPE_FACE_TRANSLUCENT: 11,
    FACE_TYPE_FACE_TEXTURED_DEDICATED: 13,
    FACE_TYPE_FACE_COLOR_FLAT_SHADED: 15,
    FACE_TYPE_FACE_TEXTURED_ATLAS: 18,
    FACE_TYPE_FACE_COLOR_SMOOTH_SHADED: 19,
    FACE_TYPE_LINE_NORMAL: 20,
    FACE_TYPE_POINT_LIGHT: 25,
    FACE_TYPE_POINT_EMITTER: 26
}

faceTypeToFlagValue = {
    2: 22,
    11: 2,
    13: 8194,
    15: 3,
    18: 8194,
    19: 16386,
    20: 32770,
    25: 2,
    26: 2
}

# INSTRUCTIONS
# Add entries to this dictionary and then use their keys as the names of vertex groups within an object.
# The entries below are included for demonstration purposes.
specialGroups = {
    # Dedicated texture at index 78 in sim3d.bmp
    "gTex78": {"faceType": FACE_TYPE_FACE_TEXTURED_DEDICATED, "texFile": 0, "texIndex": 78},
    
    # Texture at index 32 within a texture atlas at index 2 in sim3d.bmp
    "gTex2_60": {"faceType": FACE_TYPE_FACE_TEXTURED_ATLAS, "texFile": 2, "texIndex": 32},
    
    # A flat-shaded face using the colour at index 96 in the palette.
    "gFlat96": {"faceType": FACE_TYPE_FACE_COLOR_FLAT_SHADED, "texFile": 0, "texIndex": 96},
}

def write_vertex(file, x, y, z):
    # Blender: +Z = up, RHR.
    # SC: +X = right, +Y = up, +Z = forward, LHR.
    file.write(round(CONST_SCALE_FACTOR*x).to_bytes(4, byteorder='little', signed=True))
    file.write(round(CONST_SCALE_FACTOR*z).to_bytes(4, byteorder='little', signed=True))
    file.write(round(CONST_SCALE_FACTOR*y).to_bytes(4, byteorder='little', signed=True))

palette = []
with open(palettePath, 'r') as pf:
    lines = pf.readlines()
    for i in range(3, len(lines)):
        palette.append([int(c) for c in lines[i].split()])

class RENDER_OT_test(bpy.types.Operator):
    bl_idname = 'render.oha_test'
    bl_label = 'Test'
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        self.report({'INFO'}, 'Printing report to Info window.')
        return {'FINISHED'}

if (len(bpy.context.selected_objects) < 1):
    print("Please select an object.")
    # TODO message box and stop

theObject = bpy.context.selected_objects[0]

theMesh = theObject.data
meshName = theObject.name
outFile = outPath + meshName + '.bin'

vertexCount = len(theMesh.vertices) + 1 # Add one for origin.
faceCount = len(theMesh.polygons)

with open(outFile, 'wb') as file:
    
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
    nameBytes = bytearray(meshName.encode('ASCII') + b'\0')
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
        reversedListOfVertexIndices = list(reversed(face.vertices))
        reversedListOfLoopIndices = list(reversed(face.loop_indices))
        
        fVertexCount = len(face.vertices)
        fSizeBytes = 4+4+2+2+2+4+3+fVertexCount*2+fVertexCount*8
        flagValue = 3
        isLight = 0
        texFile = 0
        faceType = 15; # This matters, if it's not compatible with the flag value the game crashes when the mesh is spawned.
        
        paletteSearchStartIndex = 0
        
        groupName = ""
        
        # Check if first vertex in this face belongs to a group.
        indexFirstVertex = reversedListOfVertexIndices[0]
        if (len(theMesh.vertices[indexFirstVertex].groups) > 0):
            for curGroup in theMesh.vertices[indexFirstVertex].groups:
                groupName = theObject.vertex_groups[curGroup.group].name
                print(groupName)
                if groupName in faceTypeNameToNumber:
                    faceType = faceTypeNameToNumber[groupName]
                    flagValue = faceTypeToFlagValue[faceType]
                elif groupName in specialGroups:
                    faceType = faceTypeNameToNumber[specialGroups[groupName]["faceType"]]
                    flagValue = faceTypeToFlagValue[faceType]
                    
                # SimCopter has colours at the end of the palette that are used without shading
                if (groupName == 'unshaded'):
                    paletteSearchStartIndex = 246
        
        if (groupName in specialGroups):
            texFile = specialGroups[groupName]["texFile"]
            colorIndex = specialGroups[groupName]["texIndex"]
        else:
            # If colour isn't in the palette, this just crashes rather than trying to find the nearest match.
            color = theMesh.vertex_colors[0].data[reversedListOfLoopIndices[0]].color[0:3]
            color = [round(255*c) for c in color]
            colorIndex = paletteSearchStartIndex + palette[paletteSearchStartIndex:].index(color)
        
        file.write(b'FACE')
        file.write(fSizeBytes.to_bytes(4, byteorder='little'))
        file.write(fVertexCount.to_bytes(2, byteorder='little'))
        file.write(flagValue.to_bytes(2, byteorder='little'))
        file.write(isLight.to_bytes(2, byteorder='little'))
        file.write(colorIndex.to_bytes(4, byteorder='little')) # "Group" TODO sometimes face index
        file.write(faceType.to_bytes(1, byteorder='little')) # Face type
        file.write(colorIndex.to_bytes(1, byteorder='little')) # Color
        file.write(texFile.to_bytes(1, byteorder='little'))
        
        for vertIndex in reversedListOfVertexIndices:
            # Add one to index since first vertex in table is origin.
            file.write((vertIndex+1).to_bytes(2, byteorder='little'))
        
        # Texture coordinates
        
        faceVertexCount = len(reversedListOfVertexIndices)
        
        for i in range(faceVertexCount):
            vertIndex = reversedListOfVertexIndices[i]
            print("i=" + str(i) + " vertIndex=" + str(vertIndex))
            if faceType == 13 or faceType == 18:
                
                loopIndex = reversedListOfLoopIndices[i]
                
                # This should - and does - equal the value of vertIndex.
                #vertIndexFromLoop = theMesh.loops[loopIndex].vertex_index
                
                # https://docs.blender.org/api/current/bpy.types.MeshUVLoopLayer.html#bpy.types.MeshUVLoopLayer
                uv = theMesh.uv_layers.active.data[loopIndex].uv
                u = uv[0]
                v = uv[1]
                
                file.write(round(CONST_UV_SCALE_FACTOR*u).to_bytes(4, byteorder='little', signed=True))
                file.write(round(CONST_UV_SCALE_FACTOR*v).to_bytes(4, byteorder='little', signed=True))
            else:
                file.write((0).to_bytes(4, byteorder='little', signed=True))
                file.write((0).to_bytes(4, byteorder='little', signed=True))
    
    # Set size
    fileSize = file.tell() - 12 # Subtract 12 for mysterious 12-byte sequence that isn't counted.
    file.seek(4, 0)
    file.write(fileSize.to_bytes(4, byteorder='little'))
    