paths = ['sim3d1.max',
         'sim3d2.max',
         'sim3d3.max']

faces = []
faces.append(['vertexCount', 'flags', 'isLight', 'group', 'face type', 'tex/color', 'texFile'])

for path in paths:
    with open(path, 'rb') as file:
        data = file.read()

    for i in range(0, len(data)-4):
        if (data[i:(i+4)] == b'FACE'):
            vertexCount = int.from_bytes(data[(i+8):(i+10)], byteorder='little')
            flags = int.from_bytes(data[(i+10):(i+12)], byteorder='little')
            isLight = int.from_bytes(data[(i+12):(i+14)], byteorder='little')
            group = int.from_bytes(data[(i+14):(i+18)], byteorder='little')
            faceType = int.from_bytes(data[(i+18):(i+19)], byteorder='little')
            texColor = int.from_bytes(data[(i+19):(i+20)], byteorder='little')
            texFile = int.from_bytes(data[(i+20):(i+21)], byteorder='little')
            faces.append([vertexCount, flags, isLight, group, faceType, texColor, texFile])

outPath = 'face-info.csv'

with open(outPath, 'w') as out:
    for row in faces:
        rowStr = ', '.join([str(v) for v in row])
        out.write(rowStr + '\n')
    
    
