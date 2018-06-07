import std.algorithm;
import std.array;
import std.stdio;
import std.string;

import Statement : Statement, readStatements, writeStatements, walk;

/*
void imenu(string infileName, string outfileName)
{
  auto statements = readStatements(infileName);

  writeln("(");

  foreach (n; statements.walk)
  {
    auto statement = n.back;
    auto name = n.filter!(e => e.type != "namespace").map!(e => e.name).joiner("::");
    switch(statement.type)
    {
      case "function":
      case "struct":
      case "class":
        writeln("(\"", name, "\" . ", statement.position + 1, ")");
      break;
      default:
        break;
    }
  }

  writeln(")");
}
*/

void display(Statement statement, string prefix)
{
  if (statement.type == "function" ||
      statement.type == "struct" ||
      statement.type == "class")
  {
    if (prefix.empty)
    {
      writeln("(\"", statement.name, "\" . ", statement.position + 1, ")");
    }
    else
    {
      writeln("(\"", prefix, "\" . ", statement.position + 1, ")");
    }
  }
  foreach (stmt; statement.getStatements)
  {
    if (statement.type != "namespace")
    {
      if (prefix.empty)
      {
        display(stmt, stmt.name);
      }
      else
      {
        display(stmt, prefix ~ "::" ~ stmt.name);
      }
    }
    else
    {
      display(stmt, prefix);
    }
  }
}

void imenu(string infileName, string outfileName)
{
  auto statements = readStatements(infileName);
  writeln("(");
  foreach (stmt; statements)
  {
    display(stmt, "");
  }
  writeln(")");
}

int main(string[] args)
{
  // import core.memory;
  // GC.disable;

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
    outfileName = infileName;
  }

  imenu(infileName, outfileName);

  return 0;
}
