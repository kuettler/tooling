// import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
// import std.range;
import std.stdio;
// import std.typecons;

import MergedRange;
import Scanner;

void main(string[] args)
{
  enforce(args.length > 1,
          text("Usage:", args[0], " [-o outfile] files..."));

  string outfileName;

  if (args[1] == "-o" && args.length > 2)
  {
	outfileName = args[2];
	args = args[3 .. $];
  }
  else
  {
	args = args[1 .. $];
  }

  auto tokens = args.mergedRange.array;

  File outfile = outfileName.empty ? stdout : File(outfileName, "w");
  outfile.writeTokens(tokens);
  outfile.flush;
}
