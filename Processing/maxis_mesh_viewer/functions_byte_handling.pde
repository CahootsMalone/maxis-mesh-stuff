// Little-endian
static int bytesToInt32(byte[] bytes) {
  int value = 0;
  for (int i = 3; i >= 0; --i) {
    value <<= 8;
    value |= bytes[i] & 0xFF; // Converts from [-128, 127] to [0, 255]
  }

  return value;
}

// Little-endian
static int bytesToInt16(byte[] bytes) {
  int value = 0;
  for (int i = 1; i >= 0; --i) {
    value <<= 8;
    value |= bytes[i] & 0xFF; // Converts from [-128, 127] to [0, 255]
  }

  return value;
}

static int byteToUInt8(byte input) {
  int value = 0;
  value |= input & 0xFF; // Converts from [-128, 127] to [0, 255]
  return value;
}

static String bytesToString(byte[] bytes) {
  int end = 0;
  for (int i = 0; i < bytes.length; ++i) {
    end = i;
    if (bytes[i] == 0x00) {
      break;
    }
  }
  String result = new String(Arrays.copyOfRange(bytes, 0, end)); // copyOfRange is [first, last)
  return result;
}

static byte[] getByteRange(byte[] source, int startIndex, int count) {
  byte[] output = new byte[count];
  for (int i = 0; i < count; ++i) {
    output[i] = source[startIndex+i];
  }
  return output;
}
