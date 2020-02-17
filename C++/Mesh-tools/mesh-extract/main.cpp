// Extract and save the mesh at the specified index from the specified Maxis mesh file.

#include <iostream>
#include <fstream>
#include <vector>

#include "cxxopts.hpp"

bool parse(int argc, char* argv[], std::string& sourcePath, int& index, std::string& outputPath) {
	try
	{
		const std::string SOURCE = "source";
		const std::string INDEX = "index";
		const std::string OUTPUT = "output";
		const std::string HELP = "help";

		cxxopts::Options options("mesh-extract", "Extract and save the mesh at the specified index from the specified Maxis mesh file.");

		options.add_options()
			("s," + SOURCE, "Source path. A Maxis mesh file (sim3d#.max).", cxxopts::value<std::string>(), "<path>")
			("i," + INDEX, "Index of mesh to extract.", cxxopts::value<int>(), "<integer>")
			("o," + OUTPUT, "Output path.", cxxopts::value<std::string>(), "<path>")
			("h," + HELP, "Display help.")
			;

		options.custom_help("(--source <path> --index <integer> --output <path> | --help)");

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
			index = result[INDEX].as<int>();
		}
		else {
			std::cout << "Error: No index specified." << std::endl;
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
	int indexMeshToExtract;
	std::string pathOutput;

	bool parseSucceeded = parse(argc, argv, pathSource, indexMeshToExtract, pathOutput);

	if (!parseSucceeded)
	{
		std::cout << "ERROR: Unable to parse command-line arguments." << std::endl;
		return 0;
	}

	std::fstream file;
	file.open(pathSource, std::fstream::binary | std::fstream::in | std::fstream::out | std::fstream::ate);

	if (file.fail())
	{
		std::cout << "ERROR: Unable to open source file at path " << pathSource << std::endl;
		return 0;
	}

	std::streampos size = file.tellg(); // Positioned at end from use of fstream::ate on opening (incidentally, "ate" comes from "at end").

	file.seekg(0);

	std::unique_ptr<char[]> data = std::make_unique<char[]>(size);

	file.read(data.get(), size);

	file.close();

	std::vector<int> objectOffsets;

	// Get offsets for each object.
	for (int i = 0; i < ((int)size - 4); ++i)
	{
		if (std::strncmp(data.get() + i, "OBJX", 4) == 0)
		{
			objectOffsets.push_back(i);
		}
	}

	if (indexMeshToExtract < 0){
		std::cout << "ERROR: Index must be greater than 0." << std::endl;
		return 0;
	}

	if (indexMeshToExtract > objectOffsets.size()-1) {
		std::cout << "ERROR: Specified index is " << indexMeshToExtract << ", but there are only " << objectOffsets.size() << " meshes in " << pathSource << " (valid indices are 0 to " << objectOffsets.size()-1 << ")." << std::endl;
		return 0;
	}

	int offsetStart = objectOffsets[indexMeshToExtract];
	int offsetEnd;
	if (indexMeshToExtract == objectOffsets.size()-1)
	{
		offsetEnd = size;
	}
	else
	{
		offsetEnd = objectOffsets[(size_t)indexMeshToExtract + 1];
	}
	
	std::vector<char> dataToExtract(data.get() + offsetStart, data.get() + offsetEnd);

	std::fstream newFile;
	newFile.open(pathOutput, std::fstream::binary | std::fstream::out);

	if (newFile.fail())
	{
		std::cout << "ERROR: Unable to open destination file at path " << pathOutput << std::endl;
		return 0;
	}

	newFile.write(dataToExtract.data(), dataToExtract.size());
	newFile.close();

	return 0;
}