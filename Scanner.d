import Tokenizer;
import TreeRange;
import std.algorithm, std.conv, std.exception, std.file, std.range, std.stdio, std.regex, std.string;

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
  this(string[] expr, Token[] tokens, Entity[] content)
  {
	auto line = expr.joiner(" ").to!string;

	type_ = "code";
	name_ = "";

	auto m = line.matchFirst(structRe);
	if (!m.empty)
	{
	  type_ = expr[0];
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

	tokens_ = tokens;
	content_ = content;
  }

  string name()
  {
	if (type_ == "function")
	{
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
  Token[] tokens_;
  Entity[] content_;
  string returnType_;
  string[] arguments_;
  string[] suffix_;
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
		auto expr = tokens[start .. i].map!(value).array;
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

	  auto expr = tokens[start .. i].map!(value).array;
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

struct SourceFile
{
  this(string path)
  {
	auto content = std.file.readText(path);
	tokenize(content, path, tokens_);
	scanTokens();
  }

  this(Token[] tokens)
  {
	tokens_ = tokens;
	scanTokens();
  }

  private void scanTokens()
  {
	auto namespaceTokens = find!(t => t.value == "namespace")(tokens_);
	ulong start = 0;
	content_ = readTokenStream(namespaceTokens, start);
  }

  Token[] tokens_;
  Entity[] content_;
}
