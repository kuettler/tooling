import std.algorithm, std.array, std.file, std.stdio, std.exception, std.conv;

import Scanner;
import TreeRange;
import Tokenizer;

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

struct TokenRangeResult
{
  this(SourceFile sourceFile)
  {
	entries_ = treeRange!(t => t.type_ == "namespace",
						  t => t.content_)(sourceFile.content_)
	  .array
	  ;

	tokens_ = sourceFile.tokens_;

	if (!entries_.empty &&
		&entries_.front.back.tokens_[0] == &tokens_[0])
	{
	  entityStack_ = entries_.front;
	  entries_.popFront;
	}
  }

  bool empty() { return tokens_.empty; }
  EntityToken front() { return EntityToken(tokens_.front, entityStack_.empty ? null : entityStack_.back); }
  TokenRangeResult save() { return this; }
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

auto tokenRange(SourceFile sourceFile)
{
  return TokenRangeResult(sourceFile);
}
