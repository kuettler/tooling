import std.algorithm, std.array, std.file, std.stdio, std.exception, std.conv;

import Scanner;
import TreeRange;
import Tokenizer;

auto tokenRange(SourceFile sourceFile)
{
  struct EntityToken
  {
	this(Token token, Entity entity)
	{
	  token_ = token;
	  entity_ = entity;
	}

	Token token_;
	Entity entity_;
  }

  struct Result
  {
	this(SourceFile sourceFile)
	{
	  entries_ = treeRange!(t => t.type_ == "namespace",
  							t => t.content_)(sourceFile.content_)
		.array
		;

	  tokens_ = sourceFile.tokens_[0 .. $-1];

	  if (!entries_.empty &&
		  &entries_.front.back.tokens_[0] == &tokens_[0])
	  {
		entityStack_ = entries_.front;
		entries_.popFront;
	  }
	}

	bool empty() { return tokens_.empty; }
	EntityToken front() { return EntityToken(tokens_.front, entityStack_.empty ? null : entityStack_.back); }
	Result save() { return this; }
	void popFront()
	{
	  tokens_ = tokens_[1 .. $];
	  if (!tokens_.empty)
	  {
		if (entityStack_.empty)
		{
		  if (!entries_.empty &&
			  &entries_.front.back.tokens_[0] == &tokens_[0])
		  {
			entityStack_ = entries_.front;
			entries_.popFront;
		  }
		}
		else if (&entityStack_.back.tokens_[$-1] < &tokens_[0])
		{
		  if (!entries_.empty &&
			  &entries_.front.back.tokens_[0] == &tokens_[0])
		  {
			entityStack_ = entries_.front;
			entries_.popFront;
		  }
		  else
		  {
			entityStack_.popBack;
		  }
		}
		else if (!entries_.empty &&
				 &entries_.front.back.tokens_[0] <= &entityStack_.back.tokens_[$-1] &&
				 &entries_.front.back.tokens_[0] == &tokens_[0])
		{
		  entityStack_ = entries_.front;
		  entries_.popFront;
		}
	  }
	}

	Entity[][] entries_;
	Entity[] entityStack_;
	Token[] tokens_;
  }

  return Result(sourceFile);
}

void main(string[] args)
{
  enforce(args.length > 1,
          text("Usage:", args[0], " files..."));

  foreach (fi; 1 .. args.length)
  {
    auto filename = args[fi];
	auto sourceFile = new SourceFile(filename);

	string eofWS = sourceFile.tokens_.back.precedingWhitespace_;

	auto newFile = filename ~ ".tmp";
    auto f = File(newFile, "w");

	Entity[string][] entityStack;
	foreach (ref t; sourceFile.tokenRange)
	{
	  if (!t.entity_)
	  {
		f.write(t.token_.precedingWhitespace_, t.token_.value);
	  }
	  else if (t.entity_.type_ == "namespace")
	  {
		if (t.token_.value == "{")
		{
		  entityStack.length += 1;
		}
		else if (t.token_.value == "}")
		{
		  foreach (name; entityStack.back.keys.array.sort)
		  {
			auto e = entityStack.back[name];
			foreach (et; e.tokens_)
			{
			  f.write(et.precedingWhitespace_, et.value);
			}
		  }
		  entityStack.popBack;
		}
		f.write(t.token_.precedingWhitespace_, t.token_.value);
	  }
	  else if (t.entity_.type_ == "function")
	  {
		if (t.entity_.name !in entityStack.back)
		{
		  entityStack.back[t.entity_.name] = t.entity_;
		}
	  }
	  else
	  {
		f.write(t.token_.precedingWhitespace_, t.token_.value);
	  }
	}
	f.write(eofWS);
    f.close;
    std.file.rename(newFile, filename);
  }
}
