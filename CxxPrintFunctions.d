import std.algorithm, std.array, std.range, std.file, std.stdio, std.exception, std.conv, std.typecons;

import Scanner;
import Tokenizer;
import TokenRange;

// Print the defined functions with fully qualified names

// This is mainly for testing

void printFunctions(string filename)
{
  auto tokens = readTokens(filename);

  //auto newFile = filename ~ ".tmp";
  //auto f = File(newFile, "w");
  auto f = stdout;

  //foreach (ref r; namespaceTokenRange(tokens)) {
  foreach (ref r; classTokenRange(tokens)) {
	if (r.entity_) {
	  writeln(r.entity_.type_, " ", r.entity_.name, " ", r.token_.value);
	}
	else {
	}
  }

  // f.writeTokens(tokens);

  //f.close;
  //std.file.rename(newFile, filename);
}

/*
void main(string[] args)
{
  enforce(args.length > 1,
          text("Usage:", args[0], " [-o outfile] files..."));

  foreach (fi; 1 .. args.length)
  {
    auto filename = args[fi];
	printFunctions(filename);
  }
}
*/

void main(string[] args)
{
  printFunctions("/home/ukuettler/projects/xcard-base/FinanceService/TransactionFactoryI.h");
}
