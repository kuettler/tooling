import std.algorithm;
import std.conv;
import std.exception;
import std.file;
import std.range;
import std.regex;
import std.stdio;
import std.string;

import Tokenizer;
import TreeRange;

class Entity
{
  auto structRe = regex(r"^(namespace|class|struct|enum)( (?P<name>\w+))?");

  auto functionRe = regex(r"(template <[^>]+> )?" ~
						  r"(?P<return>([a-zA-Z0-9_&<,>* ]+|(::))+ )?" ~
						  r"(?P<name>(((~ )|(:: ))?[a-zA-Z0-9_]+|( :: ))+)" ~
						  r"(o?perator *.[^(]*)?" ~
						  r" \( (?P<args>[a-zA-Z0-9_ :&<,>*]*)\)" ~
						  r"(?P<suffix> [a-zA-Z]+)*"
						  );

public:

  this(Token[] expr, Token[] tokens, Entity[] content)
  {
	auto line = expr.map!(value).joiner(" ").to!string;

	type_ = "code";
	name_ = "";

	auto m = line.matchFirst(structRe);
	if (!m.empty)
	{
	  type_ = expr[0].value;
	  name_ = m["name"];
	}
	else
	{
	  m = line.matchFirst(functionRe);
	  if (!m.empty)
	  {
		type_ = "function";
		name_ = m["name"];

		returnType_ = m["return"].strip;
		arguments_ = m["args"].strip.splitter(" , ").array;
		suffix_ = m["suffix"].strip.splitter(" ").array;
	  }
	}

	expr_ = expr;
	tokens_ = tokens;
	content_ = content;
  }

  string name()
  {
	if (type_ == "function")
	{
	  //return expr_[0].value ~ expr_[1 .. $].map!(t => t.precedingWhitespace_ ~ t.value).joiner.to!string;
	  return name_ ~ "(" ~ arguments_.joiner(",").text ~ ") " ~ suffix_.joiner(" ").text;
	}
	else
	{
	  return name_;
	}
  }

  void print(string indent="")
  {
	if (type_ == "function")
	{
	  writeln(indent, "<", type_, "> `", returnType_, "` ", name_, "(", arguments_, ") ", suffix_);
	}
	else
	{
	  writeln(indent, "<", type_, "> ", name_);
	}
	foreach (c; content_)
	{
	  c.print(indent~"  ");
	}
  }

  string type_;
  string name_;
  Token[] expr_;
  Token[] tokens_;
  Entity[] content_;
  string returnType_;
  string[] arguments_;
  string[] suffix_;
}

bool isNamespace(Entity e)
{
  return e.type_ == "namespace";
}

bool isClass(Entity e)
{
  return e.type_ == "class";
}

bool isFunction(Entity e)
{
  return e.type_ == "function";
}

bool isInline(Entity e)
{
  // if the difference in length is just one, its tk!";", otherwise there is a
  // pair of braces
  return e.expr_.length+1 < e.tokens_.length;
}

Entity[] readTokenStream(Token[] tokens, ref ulong start)
{
  Entity[] entries;
  for (ulong i = start; i < tokens.length; i++)
  {
	auto token = tokens[i];
	if (token.type_ is tk!";")
	{
	  if (i - start > 1)
	  {
		if (value(tokens[start]) == "}")
		{
		  start += 1;
		}
		auto expr = tokens[start .. i];
		auto e = new Entity(expr, tokens[start .. i+1], []);
		if (e.type_ != "code")
		{
		  entries ~= e;
		}
	  }
	  start = i+1;
	}
	else if (token.type_ is tk!"{" && i)
	{
	  if (value(tokens[start]) == "}")
	  {
		start += 1;
	  }

	  auto expr = tokens[start .. i];
	  i += 1;
	  auto content = readTokenStream(tokens, i);
	  auto e = new Entity(expr,
						  tokens[start .. i+1],
						  content);
	  if (e.type_ != "code")
	  {
		entries ~= e;
	  }
	  start = i;
	}
	else if (token.type_ is tk!"}")
	{
	  start = i;
	  return entries;
	}
  }
  return entries;
}

string value(Token t)
{
  if (t.type_ is tk!"identifier")
	return t.value_;
  else
	return t.type_.sym;
}

auto entityNames(Entity[] entries)
{
  return entries.map!(i => i.name_);
}

auto scanTokens(Token[] tokens)
{
  // Start at the first namespace.
  // FIXME: Right now we only scan the first namespace.
  auto namespaceTokens = find!(t => t.value == "namespace")(tokens);
  ulong start = 0;
  return readTokenStream(namespaceTokens, start);
}

string detab(string input)
{
  string output;
  size_t j;

  int column;
  for (size_t i = 0; i < input.length; i++)
  {
	char c = input[i];

	switch (c)
	{
	  case '\t':
		while ((column & 1) != 1)
		{
		  output ~= ' ';
		  j++;
		  column++;
		}
		c = ' ';
		column++;
		break;

	  case '\r':
	  case '\n':
		while (j && output[j - 1] == ' ')
		  j--;
		output = output[0 .. j];
		column = 0;
		break;

	  default:
		column++;
		break;
	}
	output ~= c;
	j++;
  }
  while (j && output[j - 1] == ' ')
	j--;
  return output[0 .. j];
}


auto readTokens(string path)
{
  string content;
  if (path == "-")
  {
	foreach (ulong i, string line; lines(stdin))
	{
	  content ~= detab(line);
	}
  }
  else
  {
	content = detab(std.file.readText(path));
  }
  Token[] tokens;
  tokenize(content, path, tokens);
  return tokens;
}

void writeTokens(File f, Token[] tokens)
{
  foreach (ref t; tokens[0 .. $-1]) {
	f.write(t.precedingWhitespace_, t.value);
  }
  f.write(tokens[$-1].precedingWhitespace_);
}

// FIXME: Remove
struct SourceFile
{
  this(string path)
  {
	tokens_ = readTokens(path);
	content_ = scanTokens(tokens_);
  }

  this(Token[] tokens)
  {
	tokens_ = tokens;
	content_ = scanTokens(tokens_);
  }

  Token[] tokens_;
  Entity[] content_;
}
