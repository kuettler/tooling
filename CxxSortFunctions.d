import std.algorithm, std.array, std.file, std.stdio, std.exception, std.conv;

import Scanner;
import TreeRange;
import Tokenizer;
import TokenRange;

auto sortFunctionsRange(SourceFile sourceFile)
{
  struct Result
  {
	this(SourceFile sourceFile)
	{
	  tokenRange_ = sourceFile.tokenRange;
	}

	bool empty() { return tokenRange_.empty; }
	Token front()
	{
	  if (!functionTokens_.empty)
	  {
		return functionTokens_.front;
	  }
	  else
	  {
		return tokenRange_.front.token_;
	  }
	}
	Result save() { return this; }
	void popFront()
	{
	  if (!functionTokens_.empty)
	  {
		functionTokens_.popFront();
	  }
	  else
	  {
		tokenRange_.popFront();
		if (!tokenRange_.empty)
		{
		  auto t = tokenRange_.front;
		  if (t.entity_)
		  {
			if (t.entity_.type_ == "namespace")
			{
			  if (t.token_.value == "{")
			  {
				entityStack_.length += 1;
			  }
			  else if (t.token_.value == "}")
			  {
				auto names = entityStack_
				  .back
				  .keys
				  .array
				  .sort
				  .map!(name => entityStack_.back[name].tokens_);
				if (!names.empty)
				{
				  functionTokens_ = names.reduce!((tokens, t) => tokens ~ t);
				}
				entityStack_.popBack;
			  }
			}
			else if (t.entity_.type_ == "function")
			{
			  if (t.entity_.name !in entityStack_.back)
			  {
				entityStack_.back[t.entity_.name] = t.entity_;
			  }
			  popFront;
			}
		  }
		}
	  }
	}

	TokenRangeResult tokenRange_;
	Token[] functionTokens_;
	Entity[string][] entityStack_;
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

	auto newFile = filename ~ ".tmp";
    auto f = File(newFile, "w");

	auto tokens = sourceFile.sortFunctionsRange.array;
	foreach (ref t; tokens[0 .. $-1])
	{
	  f.write(t.precedingWhitespace_, t.value);
	}
	f.write(tokens[$-1].precedingWhitespace_);
	f.close;
    std.file.rename(newFile, filename);
  }
}
