import std.algorithm, std.array, std.file, std.stdio, std.exception, std.conv;

import Scanner : readInput, writeTokens;
import SortRange;
import TokenRange;
import Tokenizer : tokenize;

void main(string[] args)
{
    enforce(args.length > 1,
    text("Usage:", args[0], " files..."));

    foreach (fi; 1 .. args.length)
    {
        auto filename = args[fi];

	auto newFile = filename ~ ".tmp";
        auto f = File(newFile, "w");

	auto tokens = readInput(filename).tokenize(filename).sortFunctionsRange.array;
	f.writeTokens(tokens);
	f.close;
        std.file.rename(newFile, filename);
    }
}
