import std.array;
import std.stdio;

import Tokenizer : tokenize;

string quote(string s)
{
  return s.replace("\\", "\\\\").replace("\"", "\\\"");
}

void main()
{
  string content;
  foreach (string l; lines(stdin))
  {
    content ~= l;
  }
  auto tokens = tokenize(content);
  writeln("[");
  foreach (t; tokens)
  {
    writef("  {:type \"%s\" :line %d ", t.type_.sym, t.line_);
    if (t.value_.length)
      writef(":value \"%s\" ", quote(t.value_));
    if (t.precedingWhitespace_.length)
      writef(":preceding-whitespace \"%s\" ", quote(t.precedingWhitespace_));
    writeln("}");
  }
  writeln("]");
}
