import std.algorithm, std.array, std.range, std.file, std.stdio, std.exception, std.conv, std.typecons;

import Scanner;
import Tokenizer;
import TokenRange;

void printFunctions(string filename)
{
  auto tokens = readInput(filename).tokenize(filename);
  auto f = stdout;

  foreach (ref r; classTokenRange(tokens)) {
      if (r.entity_) {
	  writeln(r.entity_.type_, " ", r.entity_.name, " ", r.token_.value);
      }
      else {
      }
  }
}

void main(string[] args)
{
    printFunctions("test.h");
}
