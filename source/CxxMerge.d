module tooling.CxxMerge;

// import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
// import std.range;
import std.stdio;
// import std.typecons;

import tooling.MergedRange;
import tooling.Scanner;

int mergeMain(string[] args)
{
  enforce(args.length > 2,
          text("Usage: ", args[0], " ", args[1], " [-o outfile] files..."));

  string outfileName = "-";

  if (args[2] == "-o" && args.length > 3)
  {
	outfileName = args[3];
	args = args[4 .. $];
  }
  else
  {
	args = args[2 .. $];
  }

  auto tokens = args.mergedRange.array;

  File outfile = outfileName == "-" ? stdout : File(outfileName, "w");
  outfile.writeTokens(tokens);
  outfile.flush;
  return 0;
}
