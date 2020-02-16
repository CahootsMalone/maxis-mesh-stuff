paths = ['sim3d1.max',
         'sim3d2.max',
         'sim3d3.max']

faces = []
faces.append(['file','index','offset','col-1', 'col-2', 'col-3', 'col-4'])

for path in paths:
    with open(path, 'rb') as file:
        index = 0
        
        data = file.read()

    for i in range(0, len(data)-4):
        if (data[i:(i+4)] == b'OBJX'):
            col1 = int.from_bytes(data[(i+16):(i+17)], byteorder='little')
            col2 = int.from_bytes(data[(i+17):(i+18)], byteorder='little')
            col3 = int.from_bytes(data[(i+18):(i+19)], byteorder='little')
            col4 = int.from_bytes(data[(i+19):(i+20)], byteorder='little')
            faces.append([path, index, i, col1, col2, col3, col4])
            index += 1

outPath = 'collision-bytes.csv'

with open(outPath, 'w') as out:
    for row in faces:
        rowStr = ', '.join([str(v) for v in row])
        out.write(rowStr + '\n')
    
    
