// Replace the mesh/meshes at the specified index/indices in a Maxis mesh file with the specified data.

#include <iostream>
#include <fstream>
#include <string>
#include <set>
#include <vector>
#include <iterator>
#include <algorithm>

#include "cxxopts.hpp"

namespace Helpers
{
	int BytesToInt32(const unsigned char* bytes)
	{
		// Little endian
		return (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
	}

	int BytesToInt16(const unsigned char* bytes)
	{
		// Little endian
		return (bytes[1] << 8) | bytes[0];
	}

	void Int32ToBytes(int value, unsigned char* destination)
	{
		// Little endian
		destination[0] = 0xFF & value;
		destination[1] = 0xFF & (value >> 8);
		destination[2] = 0xFF & (value >> 16);
		destination[3] = 0xFF & (value >> 24);
	}

	void CountStuff(const std::vector<char>& data, int& totalVertexCount, int& faceCount, int& uniqueVertexCount)
	{
		uniqueVertexCount = BytesToInt16(reinterpret_cast<const unsigned char*>(data.data() + 4 + 4));
		faceCount = BytesToInt16(reinterpret_cast<const unsigned char*>(data.data() + 4 + 4 + 2));

		totalVertexCount = 0;
		for (int i = 0; i < (data.size() - 4); ++i)
		{
			if (std::strncmp(data.data() + i, "FACE", 4) == 0)
			{
				totalVertexCount += BytesToInt16(reinterpret_cast<const unsigned char*>(data.data() + i + 4 + 4));
			}
		}
	}
}

bool parse(int argc, char* argv[], std::string& sourcePath, std::vector<int>& index, std::string& replacementPath, std::string& outputPath)
{
	try
	{
		const std::string SOURCE = "source";
		const std::string INDEX = "index";
		const std::string REPLACEMENT = "replacement";
		const std::string OUTPUT = "output";
		const std::string HELP = "help";

		cxxopts::Options options("mesh-replace", "Replace the mesh/meshes at the specified index/indices in a Maxis mesh file with the specified data.");

		options.add_options()
			("s," + SOURCE, "Source path. A Maxis mesh file (sim3d#.max).", cxxopts::value<std::string>(), "<path>")
			("i," + INDEX, "Index/indices of mesh/meshes to replace.", cxxopts::value<std::vector<int>>(), "<integer>[,<integer>[,<integer>[,...]]]")
			("r," + REPLACEMENT, "Path to replacement object data.", cxxopts::value<std::string>(), "<path>")
			("o," + OUTPUT, "Output path.", cxxopts::value<std::string>(), "<path>")
			("h," + HELP, "Display help.")
			;

		options.custom_help("(--source <path> --index <integer> --replacement <path> --output <path> | --help)");

		cxxopts::ParseResult result = options.parse(argc, argv);

		if (result.count(HELP) || result.arguments().size() == 0)
		{
			std::cout << options.help() << std::endl;
			exit(0);
		}

		if (result.count(SOURCE)) {
			sourcePath = result[SOURCE].as<std::string>();
		}
		else {
			std::cout << "Error: No source file specified." << std::endl;
			return false;
		}

		if (result.count(INDEX)) {
			index = result[INDEX].as<std::vector<int>>();
		}
		else {
			std::cout << "Error: No indices specified." << std::endl;
			return false;
		}

		if (result.count(REPLACEMENT)) {
			replacementPath = result[REPLACEMENT].as<std::string>();
		}
		else {
			std::cout << "Error: No replacement file specified." << std::endl;
			return false;
		}

		if (result.count(OUTPUT)) {
			outputPath = result[OUTPUT].as<std::string>();
		}
		else {
			std::cout << "Error: No output file specified." << std::endl;
			return false;
		}
	}
	catch (const std::exception& e)
	{
		std::cout << "Error parsing options: " << e.what() << std::endl;
		return false;
	}

	return true;
}

int main(int argc, char* argv[])
{
	std::string pathSource;
	std::vector<int> indicesMeshesToReplace;
	std::string pathReplacement;
	std::string pathOutput;

	bool parseSucceeded = parse(argc, argv, pathSource, indicesMeshesToReplace, pathReplacement, pathOutput);

	if (!parseSucceeded)
	{
		std::cout << "ERROR: Unable to parse command-line arguments." << std::endl;
		return 0;
	}

	// Load replacement mesh.
	std::vector<char> dataReplacement;
	{
		std::fstream file;
		file.open(pathReplacement, std::fstream::binary | std::fstream::in | std::fstream::out | std::fstream::ate);

		if (file.fail())
		{
			std::cout << "ERROR: Unable to open replacement file at path " << pathReplacement << std::endl;
			return 0;
		}

		file.seekg(0);

		// Don't want to use istream_iterator: it skips whitespace by default.
		std::copy(std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>(), std::back_inserter(dataReplacement));

		file.close();
	}

	// Load mesh file into which replacement mesh will be inserted.
	std::streampos sizeSource;
	std::vector<char> data;
	{
		std::fstream file;
		file.open(pathSource, std::fstream::binary | std::fstream::in | std::fstream::out | std::fstream::ate);

		if (file.fail())
		{
			std::cout << "ERROR: Unable to open source file at path " << pathSource << std::endl;
			return 0;
		}

		sizeSource = file.tellg(); // Positioned at end from use of fstream::ate on opening (incidentally, "ate" comes from "at end").

		file.seekg(0);

		// Don't want to use istream_iterator: it skips whitespace by default.
		std::copy(std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>(), std::back_inserter(data));

		file.close();
	}

	// Get initial values for total vertex count, face count, and unique vertex count. (They need to be updated when altering meshes.)
	int overalltotalVertexCount = Helpers::BytesToInt32(reinterpret_cast<unsigned char*>(data.data() + 882));
	int overallFaceCount = Helpers::BytesToInt32(reinterpret_cast<unsigned char*>(data.data() + 894));
	int overallUniqueVertexCount = Helpers::BytesToInt32(reinterpret_cast<unsigned char*>(data.data() + 898));

	int repTVC, repFC, repUVC;
	Helpers::CountStuff(dataReplacement, repTVC, repFC, repUVC);

	// Modify replacement mesh.
	char* vertStart = dataReplacement.data() + 4 + 4 + 2 + 2 + 4 + 4 + 4 + 88 + 12;

	float rotationAngle = 0 * (3.1415926535 / 180.0); // radians
	float scaleFactor = 1;

	int count = Helpers::BytesToInt16(reinterpret_cast<unsigned char*>(dataReplacement.data() + 4 + 4));
	for (int v = 0; v < count; ++v)
	{
		int x = Helpers::BytesToInt32(reinterpret_cast<unsigned char*>(vertStart + v * 12 + 0));
		int y = Helpers::BytesToInt32(reinterpret_cast<unsigned char*>(vertStart + v * 12 + 4));
		int z = Helpers::BytesToInt32(reinterpret_cast<unsigned char*>(vertStart + v * 12 + 8));

		int newX = x;
		int newY = y;
		int newZ = z;

		// TODO expose Y rotation and scaling as arguments.
		/*
		// Rotate about Y axis
		newX = cos(rotationAngle) * x + sin(rotationAngle) * z;
		newY = y;
		newZ = -sin(rotationAngle) * x + cos(rotationAngle) * z;

		// Scale.
		newX *= scaleFactor;
		newY *= scaleFactor;
		newZ *= scaleFactor;
		*/

		Helpers::Int32ToBytes(newX, reinterpret_cast<unsigned char*>(vertStart + v * 12 + 0));
		Helpers::Int32ToBytes(newY, reinterpret_cast<unsigned char*>(vertStart + v * 12 + 4));
		Helpers::Int32ToBytes(newZ, reinterpret_cast<unsigned char*>(vertStart + v * 12 + 8));
	}

	// Get offsets for each object in the mesh file.
	std::vector<int> objectOffsets;
	for (int i = 0; i < ((int)data.size() - 4); ++i)
	{
		if (std::strncmp(data.data() + i, "OBJX", 4) == 0)
		{
			objectOffsets.push_back(i);
		}
	}

	for (int index : indicesMeshesToReplace)
	{
		if (index < 0) {
			std::cout << "ERROR: Indices must be greater than 0." << std::endl;
			return 0;
		}

		if (index > objectOffsets.size() - 1) {
			std::cout << "ERROR: Specified index " << index << " is invalid: there are only " << objectOffsets.size() << " meshes in " << pathSource << " (valid indices are 0 to " << objectOffsets.size() - 1 << ")." << std::endl;
			return 0;
		}
	}

	// Loop below requires that indices be in ascending order.
	std::sort(indicesMeshesToReplace.begin(), indicesMeshesToReplace.end());

	// Replace meshes in reverse order so list of offsets doesn't have to be regenerated after each replacment.
	for (int i = (indicesMeshesToReplace.size() - 1); i >= 0; --i)
	{
		int curIndex = indicesMeshesToReplace[i];
		int curOffset = objectOffsets[curIndex];
		
		int nextOffset;
		if (curIndex == objectOffsets.size() - 1)
		{
			nextOffset = sizeSource;
		}
		else
		{
			nextOffset = objectOffsets[curIndex + 1];
		}

		// Get unique 12-byte value for this mesh.
		std::vector<char> signature(data.begin() + curOffset + 112, data.begin() + curOffset + 124);

		int curTVC, curFC, curUVC;
		Helpers::CountStuff(std::vector<char>(data.begin() + curOffset, data.begin() + nextOffset), curTVC, curFC, curUVC);

		// Replace existing mesh with replacement.
		data.erase(data.begin() + curOffset, data.begin() + nextOffset);
		data.insert(data.begin() + curOffset, dataReplacement.begin(), dataReplacement.end());

		// Use 12-byte signature from original mesh.
		data.erase(data.begin() + curOffset + 112, data.begin() + curOffset + 124);
		data.insert(data.begin() + curOffset + 112, signature.begin(), signature.end());

		// Update counts.
		overalltotalVertexCount = overalltotalVertexCount - curTVC + repTVC;
		overallFaceCount = overallFaceCount - curFC + repFC;
		overallUniqueVertexCount = overallUniqueVertexCount - curUVC + repUVC;
	}

	// Update counts.
	Helpers::Int32ToBytes(overalltotalVertexCount, reinterpret_cast<unsigned char*>(data.data() + 882));
	Helpers::Int32ToBytes(overallFaceCount, reinterpret_cast<unsigned char*>(data.data() + 894));
	Helpers::Int32ToBytes(overallUniqueVertexCount, reinterpret_cast<unsigned char*>(data.data() + 898));

	// Export modified mesh file.
	std::fstream newFile;
	newFile.open(pathOutput, std::fstream::binary | std::fstream::out);

	if (newFile.fail())
	{
		std::cout << "ERROR: Unable to open destination file at path " << pathOutput << std::endl;
		return 0;
	}

	newFile.write(data.data(), data.size());
	newFile.close();

	return 0;
}