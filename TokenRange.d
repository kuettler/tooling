import std.algorithm, std.array, std.file, std.stdio, std.exception, std.conv, std.typecons;

import Scanner;
import TreeRange;
import Tokenizer;

alias EntityToken = Tuple!(Token, "token_", Entity, "entity_");

struct TokenRangeResult
{
  this(Entity[][] entries, Token[] tokens)
  {
	entries_ = entries;
	tokens_ = tokens;

	if (isEntityStart())
	  consumeEntity();
  }

  private Entity currentEntity() { return entityStack_.back; }
  private Entity nextEntity() { return entries_.front.back; }

  private bool hasCurrentEntity() { return !entityStack_.empty; }
  private bool hasNextEntity() { return !entries_.empty; }

  private bool isEntityStart() {
	return hasNextEntity &&
	  &nextEntity.tokens_[0] == &tokens_[0];
  }

  private bool isEntityDone() {
	return &currentEntity.tokens_[$-1] < &tokens_[0];
  }

  private bool isNestedEntity() {
	return &nextEntity.tokens_[0] <= &currentEntity.tokens_[$-1];
  }

  private void consumeEntity()
  {
	entityStack_ = entries_.front;
	entries_.popFront;
  }

  bool empty() { return tokens_.empty; }
  EntityToken front() { return EntityToken(tokens_.front, !hasCurrentEntity() ? null : currentEntity); }
  TokenRangeResult save() { return this; }
  void popFront()
  {
	tokens_ = tokens_[1 .. $];
	if (!tokens_.empty)
	{
	  if (!hasCurrentEntity())
	  {
		if (isEntityStart())
		  consumeEntity();
	  }
	  else if (isEntityDone())
	  {
		if (isEntityStart())
		  consumeEntity();
		else
		  entityStack_.popBack;
	  }
	  else if (isEntityStart() && isNestedEntity())
	  {
		consumeEntity();
	  }
	}
  }

private:
  Entity[][] entries_;
  Token[] tokens_;
  Entity[] entityStack_;
}

auto namespaceTokenRange(Token[] tokens, Entity[] content)
{
  return TokenRangeResult(treeRange!(t => t.type_ == "namespace", t => t.content_)(content).array, tokens);
}

auto namespaceTokenRange(Token[] tokens)
{
  auto content = scanTokens(tokens);
  return namespaceTokenRange(tokens, content);
}

auto namespaceTokenRange(SourceFile sourceFile)
{
  return namespaceTokenRange(sourceFile.tokens_, sourceFile.content_);
}

unittest
{
    auto text = "namespace\n{\n}";
    auto tokens = tokenize(text, "stdin");
    writeln(namespaceTokenRange(tokens));
    writeln(namespaceTokenRange(tokenize("", "stdin")));
}

auto classTokenRange(Token[] tokens, Entity[] content)
{
  return TokenRangeResult(treeRange!(t => t.type_ == "namespace" || t.type_ == "class", t => t.content_)(content).array, tokens);
}

auto classTokenRange(Token[] tokens)
{
  auto content = scanTokens(tokens);
  return classTokenRange(tokens, content);
}

auto classTokenRange(SourceFile sourceFile)
{
  return classTokenRange(sourceFile.tokens_, sourceFile.content_);
}
