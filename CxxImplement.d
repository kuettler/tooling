import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.range;
import std.stdio;

import Statement : Statement, FunctionStatement, readStatements, writeStatements, merge;

// Implement the cpp file to a given header

string createNamespace(Statement statement, string indent)
{
  return (indent ~ "namespace " ~ statement.name ~ "\n" ~
          indent ~ "{\n" ~
          createCxxFileContent(statement.getStatements, indent ~ "\t", []) ~
          indent ~ "}\n"
    );
}

string createClass(Statement statement, string indent, string[] classStack)
{
  return createCxxFileContent(statement.getStatements, indent, classStack ~ statement.name);
}

string createFunction(FunctionStatement statement, string indent, string[] classStack)
{
  auto className = classStack.joiner("::").to!string;
  if (className) className ~= "::";
  bool headerOnly(string name) {
    return !find(["explicit", "static", "override", "virtual", "friend"], name).empty;
  }
  auto entities = statement.entities[0 .. $-1].filter!(t => !headerOnly(t.value)).array;
  string result;
  if (entities) {
    result ~= indent;
    bool classNameInserted = false;
    // constructor or destructor
    if (entities[0].value == "~" || entities[0].value == statement.name) {
      result ~= className;
      classNameInserted = true;
    }
    result ~= entities[0].value;
    foreach (t; entities[1 .. $]) {
      if (!classNameInserted && (t.value == "~" || t.value == statement.functionName)) {
        result ~= t.precedingWhitespace ~ className ~ t.value;
        classNameInserted = true;
      }
      else {
        result ~= t.precedingWhitespace ~ t.value;
      }
    }
    result ~= "\n" ~
              indent ~ "{\n" ~
              indent ~ "\t// FIXME: Implementation missing\n" ~
              indent ~ "}\n\n";
  }
  return result;
}

string createCxxFileContent(Statement[] statements, string indent, string[] classStack)
{
  string result;
  foreach (s; statements) {
    switch (s.type) {
      case "namespace":
        result ~= createNamespace(s, indent);
        break;
      case "class":
        result ~= createClass(s, indent, classStack);
        break;
      case "function":
        if (auto f = cast(FunctionStatement)s)
        {
          if (f.isDeclaration) {
            result ~= createFunction(f, indent, classStack);
          }
        }
        break;
      default:
        break;
    }
  }
  return result;
}

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
