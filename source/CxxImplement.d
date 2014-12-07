module tooling.CxxImplement;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.range;
import std.stdio;

import tooling.Scanner;
import tooling.TreeRange;
import tooling.Tokenizer;
import tooling.TokenRange;
import tooling.MergedRange;
import tooling.UnifyRange;

// Implement the cpp file to a given header

string createNamespace(Entity entity, string indent)
{
  return (indent ~ "namespace " ~ entity.name ~ "\n" ~
		  indent ~ "{\n" ~
		  createCxxFileContent(entity.content_, indent ~ "  ", []) ~
		  indent ~ "}\n"
		  );
}

string createClass(Entity entity, string indent, string[] classStack)
{
  return createCxxFileContent(entity.content_, indent, classStack ~ entity.name);
}

string createFunction(Entity entity, string indent, string[] classStack)
{
  auto className = classStack.joiner("::").to!string;
  if (className) className ~= "::";
  bool headerOnly(string name) {
	foreach (w; ["explicit", "static", "override", "virtual"]) {
	  if (name == w) return true;
	}
	return false;
  }
  auto tokens = entity.expr_.filter!(t => !headerOnly(t.value)).array;
  string result;
  if (tokens) {
	result ~= indent;
	bool classNameInserted = false;
	if (classStack) {
	  if (tokens[0].value == "~" || tokens[0].value == entity.name_) {
		result ~= className;
		classNameInserted = true;
	  }
	}
	result ~= tokens[0].value;
	foreach (t; tokens[1 .. $]) {
	  if (!classNameInserted && (t.value == "~" || t.value == entity.name_)) {
		result ~= t.precedingWhitespace_ ~ className ~ t.value;
		classNameInserted = true;
	  }
	  else {
		result ~= t.precedingWhitespace_ ~ t.value;
	  }
	}
	result ~= "\n" ~
	  indent ~ "{\n" ~
	  indent ~ "  // FIXME: Implementation missing\n" ~
	  indent ~ "}\n\n";
  }
  return result;
}

string createCxxFileContent(Entity[] entities, string indent, string[] classStack)
{
  string result;
  foreach (entity; entities) {
	switch (entity.type_) {
	  case "namespace":
		result ~= createNamespace(entity, indent);
		break;
	  case "class":
		result ~= createClass(entity, indent, classStack);
		break;
	  case "function":
		if (!isInline(entity)) {
		  result ~= createFunction(entity, indent, classStack);
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
  auto headerTokens = readTokens(headerFileName);
  auto entities = scanTokens(headerTokens);

  auto content = createCxxFileContent(entities, "", []);

  Token[] tokens;
  tokenize(content, sourceFileName, tokens);

  if (!sourceFileName.empty)
  {
	auto sourceTokens = readTokens(sourceFileName);

	// merge with preference to source tokens if available
	auto mergedTokens = mergedRange([sourceTokens, tokens[0 .. $-1]]).array;
	tokens = unifyFunctionsRange(mergedTokens).array;
  }

  auto outfile = sourceFileName == "-" ? stdout : File(sourceFileName, "w");
  outfile.writeTokens(tokens);
  outfile.flush;
}

int implementMain(string[] args)
{
  string name = args[0];
  string cmd = args[1];
  string infileName;
  string outfileName;

  args = args[2 .. $];

  if (args.length > 1)
  {
	if (args[0] == "-o")
	{
	  outfileName = args[1];
	  args = args[2 .. $];
	}
  }

  if (!args.length)
  {
	writeln("Usage: ", name, " ", cmd, " [-o outfile] inputfile");
	return 1;
  }

  infileName = args[0];
  if (infileName != "-" && outfileName.empty)
  {
	outfileName = infileName.splitter(".").array[0 .. $-1].joiner(".").to!string ~ ".cpp";
  }

  implement(infileName, outfileName);
  return 0;
}
