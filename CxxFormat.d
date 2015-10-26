import std.algorithm.searching : canFind;
import std.file : readText;
import std.stdio : File, write, writeln, stdout, stdin, lines;

import Tokenizer : tokenize, tk, Token, TokenType;

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

void main(string[] args)
{
  foreach (name; args[1 .. $])
  {
    try
    {
      auto content = readInput(name);
      auto tokens = content.tokenize(name);
      auto outfile = name == "-" ? stdout : File(name, "w");
      foreach (i, ref t; tokens[0 .. $-1])
      {
        if (t.type_ is tk!"(")
        {
          if (i > 0)
          {
            auto value = tokens[i-1].value;
            if (value == "for" ||
                value == "while" ||
                value == "if" ||
                value == "switch"
              )
            {
              t.precedingWhitespace_ = " ";
            }
            else if (value == "catch")
            {
              t.precedingWhitespace_ = "";
            }
          }
          if (!tokens[i+1].precedingWhitespace_.canFind("\n"))
          {
            tokens[i+1].precedingWhitespace_ = "";
          }
        }
        else if (t.type_ is tk!")")
        {
          if (!t.precedingWhitespace_.canFind("\n"))
          {
            t.precedingWhitespace_ = "";
          }
        }
        else if (t.type_ is tk!":")
        {
          if (i > 1 && tokens[i-2].value == "class")
          {
            t.precedingWhitespace_ = "";
          }
          else if (i > 4)
          {
            for (ulong j = 2; j < 5; ++j)
            {
              if (tokens[i-j].value == "for" &&
                  tokens[i-j+1].type_ is tk!"(")
              {
                t.precedingWhitespace_ = " ";
                break;
              }
            }
          }
        }
        outfile.write(t.precedingWhitespace_, t.value);
      }
      outfile.write(tokens[$-1].precedingWhitespace_);
    }
    catch (Exception e)
    {
      writeln(name);
    }
  }
}
