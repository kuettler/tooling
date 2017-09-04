import std.array;
import std.stdio : File, write, writeln, writef, writefln, stdout, stdin, lines;
import std.file : readText;

import Tokenizer : tokenize;

string quote(string s)
{
  return s.replace("\\", "\\\\").replace("\"", "\\\"");
}

auto readInput(string path)
{
  if (path == "-")
  {
    string content;
    foreach (ulong i, string line; lines(stdin))
    {
      content ~= line;
    }
    return content;
  }
  else
  {
    return readText(path);
  }
}

int main(string[] args)
{
  if (args.length < 2)
  {
    writefln("Usage: %s filename", args[0]);
    return 1;
  }
  auto content = readInput(args[1]);
  auto tokens = tokenize(content);
  writeln("[");
  foreach (t; tokens)
  {
    writef("  {:type \"%s\" :line %d :position %d ", t.type_.sym.quote, t.line_, t.position_);
    if (t.value_.length)
      writef(":value \"%s\" ", quote(t.value_));
    if (t.precedingWhitespace_.length)
      writef(":preceding-whitespace \"%s\" ", quote(t.precedingWhitespace_));
    writeln("}");
  }
  writeln("]");
  return 0;
}
