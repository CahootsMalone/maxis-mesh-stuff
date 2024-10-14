# https://github.com/CahootsMalone/maxis-mesh-stuff/blob/master/Info/Maxis-Mesh-Format.md#object-objx

# From COPTER_D.PDB file present in leaked prerelease
# Provided in struct definition format by maths22
# struct GameObjectHdrType {
#     char Id[4];
#     long Size;
#     short NVerts;
#     short NFaces;
#     ulong Attrib;
#     long Radius;
#     long YRadius;
#     char ObjName[24];
#     char TextureFile[64];
#     long ObjAnimCnt;
#     long ObjAnimPtr;
#     int ID;
# }

# Dividing spatial coordinates (vertices and the bounding radius) by 2^18 roughly converts to metres.
# See https://github.com/CahootsMalone/maxis-mesh-stuff/blob/master/Info/Maxis-Mesh-Format.md#scale
# maths22 reports that under the hood the same scale factor used for the texture coordinates (2^16 = 65536) is used for spatial coordinates.
# I find the approximate conversion to metres a bit more intuitive (1 tile side ~= 16 metres) since that's what I've used when making new models.
RADIUS_SCALE_FACTOR = 2.0**18

paths = ['C:/Maxis/SimCopter/geo/sim3d1.max',
         'C:/Maxis/SimCopter/geo/sim3d2.max',
         'C:/Maxis/SimCopter/geo/sim3d3.max',
         'C:/Maxis/Streets/GEO/sim3d1.max',
         'C:/Maxis/Streets/GEO/sim3d2.max',
         'C:/Maxis/Streets/GEO/sim3d3.max']

rows = []
rows.append(['file', 'index', 'offset', 'vertex count', 'face count', 'attributes','radius', 'radius scaled', 'y radius', 'name', 'texture file', 'anim count?', 'anim pointer?', 'ID'])

for path in paths:
    with open(path, 'rb') as file:
        index = 0
        
        data = file.read()

    for i in range(0, len(data)-4):
        if (data[i:(i+4)] == b'OBJX'):
            vertex_count = int.from_bytes(data[(i+8):(i+10)], byteorder='little', signed=False)
            face_count = int.from_bytes(data[(i+10):(i+12)], byteorder='little', signed=False)
            attributes = int.from_bytes(data[(i+12):(i+16)], byteorder='little', signed=False)
            radius = int.from_bytes(data[(i+16):(i+20)], byteorder='little', signed=False)
            radius_scaled = radius/RADIUS_SCALE_FACTOR
            y_radius = int.from_bytes(data[(i+20):(i+24)], byteorder='little', signed=False)
            name = data[(i+24):(i+48)].decode('ascii', 'ignore');
            texture_file = data[(i+48):(i+112)].decode('ascii', 'ignore');
            anim_count = int.from_bytes(data[(i+112):(i+116)], byteorder='little', signed=False)
            anim_pointer = int.from_bytes(data[(i+116):(i+120)], byteorder='little', signed=False)
            id = int.from_bytes(data[(i+120):(i+124)], byteorder='little', signed=True)

            rows.append([path, index, i, vertex_count, face_count, attributes, radius, radius_scaled, y_radius, name, texture_file, anim_count, anim_pointer, id])

            index += 1

outPath = 'object-header-info.csv'

with open(outPath, 'w') as out:
    for row in rows:
        rowStr = ', '.join([str(v) for v in row])
        out.write(rowStr + '\n')
    
    
