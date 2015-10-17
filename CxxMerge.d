// import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
// import std.range;
import std.stdio;
// import std.typecons;

import Statement : readStatements, writeStatements, merge;

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

  auto statements = readStatements(args.front);
  foreach (filename; args[1 .. $])
  {
    statements = merge(statements, readStatements(filename));
  }

  File outfile = outfileName.empty ? stdout : File(outfileName, "w");
  outfile.writeStatements(statements);
  outfile.flush;
}
