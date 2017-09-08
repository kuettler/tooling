import std.algorithm;
import std.array;
import std.stdio;
import std.string;

import Parser : parseFile, getAllFunctions, getAllMethods;

void imenu(string infileName)
{
  parseFile(infileName);

  writeln("(");

  foreach (fn; getAllFunctions)
  {
    writeln("(\"", fn.name, "\" . ", fn.def_pos, ")");
  }

  foreach (fn; getAllMethods)
  {
    writeln("(\"", fn.name, "\" . ", fn.def_pos, ")");
  }

  writeln(")");
}

int main(string[] args)
{
  // import core.memory;
  // GC.disable;

  string name = args[0];
  string infileName;

  if (args.length == 1)
  {
    writeln("Usage: ", name, " inputfile");
    return 1;
  }

  infileName = args[1];
  imenu(infileName);

  //imenu("/home/ukuettler/projects/xcard-base/FinanceService/TransactionFactoryI.cpp");
  //imenu("/home/ukuettler/projects/xcard-base/MediatorCardLoading/MediatorCardLoadingFunctions.cpp");

  return 0;
}
