import std.algorithm, std.array, std.file, std.stdio, std.exception, std.conv, std.typecons;

import Scanner;
import TreeRange;
import Tokenizer;
import TokenRange;

auto unifyFunctionsRange(Token[] tokens)
{
  struct Result
  {
	this(Token[] tokens)
	{
	  tokenRange_ = tokens.namespaceTokenRange;
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
	  if (functionTokens_.empty)
	  {
		tokenRange_.popFront();
		if (!tokenRange_.empty)
		{
		  auto t = tokenRange_.front;
		  if (t.entity_)
		  {
			if (isNamespace(t.entity_))
			{
			  if (t.token_.value == "{")
			  {
				entityStack_.length += 1;
			  }
			  else if (t.token_.value == "}")
			  {
				entityStack_.popBack;
			  }
			}
			else if (t.entity_.type_ == "function") // && entityStack_)
			{
			  if (t.entity_.name !in entityStack_.back)
			  {
				entityStack_.back[t.entity_.name] = t.entity_;
				functionTokens_ = t.entity_.tokens_;
			  }
			  else
			  {
				popFront;
			  }
			}
		  }
		}
	  }
	}

	TokenRangeResult tokenRange_;
	Token[] functionTokens_;
	Entity[string][] entityStack_;
  }

  return Result(tokens);
}
