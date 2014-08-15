import std.algorithm, std.array, std.file, std.stdio, std.exception, std.conv;

import Scanner;
import SortRange;

void main(string[] args)
{
  enforce(args.length > 1,
          text("Usage:", args[0], " files..."));

  foreach (fi; 1 .. args.length)
  {
    auto filename = args[fi];
	auto sourceFile = SourceFile(filename);

	auto newFile = filename ~ ".tmp";
    auto f = File(newFile, "w");

	auto tokens = sourceFile.sortFunctionsRange.array;
	foreach (ref t; tokens[0 .. $-1])
	{
	  f.write(t.precedingWhitespace_, t.value);
	}
	f.write(tokens[$-1].precedingWhitespace_);
	f.close;
    std.file.rename(newFile, filename);
  }
}
