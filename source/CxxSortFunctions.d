module tooling.CxxSortFunctions;

import std.algorithm, std.array, std.file, std.stdio, std.exception, std.conv;

import tooling.Scanner;
import tooling.SortRange;
import tooling.TokenRange;

int sortFunctionsMain(string[] args)
{
  enforce(args.length > 2,
          text("Usage: ", args[0], " ", args[1], " files..."));

  foreach (fi; 2 .. args.length)
  {
    auto filename = args[fi];

	auto newFile = filename ~ ".tmp";
    auto f = File(newFile, "w");

	auto tokens = readTokens(filename).sortFunctionsRange.array;
	f.writeTokens(tokens);
	f.close;
    std.file.rename(newFile, filename);
  }
  return 0;
}
