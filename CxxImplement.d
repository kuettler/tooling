import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.range;
import std.stdio;

//import Statement : NestedEntity, Statement, FunctionStatement, readStatements, writeStatements, merge;

import Statement : readStatements, writeStatements, merge;
import Generate : createCxxFileContent;

// Implement the cpp file to a given header

void implement(string headerFileName, string sourceFileName)
{
  auto content = createCxxFileContent(readStatements(headerFileName), "", []);
  auto outfile = sourceFileName == "-" ? stdout : File(sourceFileName, "w");

  // If output goes to stdout, there is no implementation file to read and merge
  if (!sourceFileName.empty)
  {
    auto statements = readStatements(content, sourceFileName);
    auto sourceStatements = readStatements(sourceFileName);

    // merge with preference to source tokens if available
    statements = merge(sourceStatements, statements);
    outfile.writeStatements(statements);
  }
  else
  {
    outfile.write(content);
  }

  outfile.flush;
}

unittest
{
  auto header = "namespace TestNamespace\n{\n\tclass TestClass\n\t{\n\tpublic:\n\t\texplicit TestClass(int i);\n\t\tvirtual ~TestClass() {}\n\n\t};\n}\n";
  auto implementation = "namespace TestNamespace\n{\n\tTestClass::TestClass(int i)\n\t{\n\t\t// FIXME: Implementation missing\n\t}\n\n}\n";

  assert(header.tokenize("-").scanTokens.createCxxFileContent("", []) == implementation);
}

int main(string[] args)
{
  string name = args[0];
  string infileName;
  string outfileName;

  if (args.length == 1)
  {
    writeln("Usage: ", name, " [-o outfile] inputfile");
    return 1;
  }

  if (args.length > 1)
  {
    if (args[1] == "-o" && args.length > 2)
    {
      outfileName = args[2];
      args = args[3 .. $];
    }
    else
    {
      args = args[1 .. $];
    }
  }

  infileName = args[0];
  if (infileName != "-" && outfileName.empty)
  {
    outfileName = infileName.splitter('.').dropBack(1).joiner(".").to!string ~ ".cpp";
  }

  implement(infileName, outfileName);
  return 0;
}
