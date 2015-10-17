import std.algorithm : splitter, find, chunkBy, map, joiner, cmp;
import std.array : array;
import std.conv : text;
import std.file : readText;
import std.range : chain;
import std.range.primitives : save, empty, popFront, popBack, front, back;
import std.regex : regex, matchFirst;
import std.stdio : File, write, writeln, stdout, stdin, lines;
import std.string : strip;

import Tokenizer : tokenize, tk, Token, TokenType;

class Entity
{
public:
  string precedingWhitespace() const { return ""; }
  string value() const { return ""; }
  void print(File f) const {}
  Statement[] getStatements() { return Statement[].init; }
}

class TokenEntity : Entity
{
  Token t;
public:
  this(Token t) {
    this.t = t;
  }

  TokenType type() const { return t.type_; }
  override string precedingWhitespace() const { return t.precedingWhitespace_; }
  override string value() const { return t.value; }
  override void print(File f) const {
    if (type is tk!"\0")
    {
      //f.write(t.precedingWhitespace_);
    }
    else
    {
      f.write(t.precedingWhitespace_, t.value);
    }
  }
}

class NestedEntity : Entity
{
  Entity[] entities_;
public:
  this(Entity[] entities_) {
    this.entities_ = entities_;
  }

  override string precedingWhitespace() const { return entities_.front.precedingWhitespace; }
  override string value() const { return "{ ... }"; }
  override void print(File f) const {
    foreach (e; entities_) {
      e.print(f);
    }
  }

  override Statement[] getStatements() { return splitStatements(entities_[1 .. $-1]); }
  Entity[] entities() { return entities_; }
}

Entity[] nestTokens(Token[] tokens, ref ulong start)
{
  Entity[] entities;
  for (ulong i = start; i < tokens.length; i++)
  {
    auto t = tokens[i];
    if (t.type_ is tk!"{" && i > start)
    {
      entities ~= new NestedEntity(nestTokens(tokens, i));
    }
    else if (t.type_ is tk!"}")
    {
      start = i;
      return entities ~ new TokenEntity(t);
    }
    else
    {
      entities ~= new TokenEntity(t);
    }
  }
  start = tokens.length;
  return entities;
}

Entity[] createEntities(Token[] tokens)
{
  ulong start = 0;
  return nestTokens(tokens, start);
}

auto structRe = regex(r"^(?P<type>namespace|class|struct|enum|union)( (?P<name>\w+))?");

auto functionRe = regex(r"(template <[^>]+> )?" ~
                        r"(?P<return>([a-zA-Z0-9_&<,>* ]+|(::))+ )?" ~
                        r"(?P<name>(((~ )|(:: ))?[a-zA-Z0-9_]+|( :: ))+)" ~
                        r"(o?perator *.[^(]*)?" ~
                        r" \( (?P<args>[a-zA-Z0-9_ :&<,>*]*)\)" ~
                        r"(?P<suffix> [a-zA-Z]+)*"
  );

auto getStatementType(Entity[] entities)
{
  auto line = entities.map!(e => e.value).joiner(" ").text;
  auto m = line.matchFirst(structRe);
  if (!m.empty)
  {
    return ["type": m["type"], "name": m["name"]];
  }

  m = line.matchFirst(functionRe);
  if (!m.empty)
  {
    return ["type": "function",
            "name": m["name"],
            "return": m["return"].strip,
            "args": m["args"].strip,
            "suffix": m["suffix"].strip,
      ];
  }

  return ["type": "code", "name": ""];
}

class Statement
{
private:
  string type_;
  string name_;
  Entity[] entities_;

public:
  this(string type, string name, Entity[] entities) {
    this.type_ = type;
    this.name_ = name;
    this.entities_ = entities;
  }

  void print(File f) {
    //writeln("---");
    foreach (e; entities_) {
      e.print(f);
      //write(e.precedingWhitespace, e.value);
    }
  }

  string type() const { return type_; }
  string name() { return name_; }
  Entity[] entities() { return entities_; }

  Statement[] getStatements() {
    return entities_.map!(e => e.getStatements).joiner.array;
  }
}

class FunctionStatement : Statement
{
private:
  string returnType_;
  string[] args_;
  string[] suffix_;

public:
  this(string type, string name, string returnType, string[] args, string[] suffix, Entity[] entities) {
    super(type, name, entities);
    this.returnType_ = returnType;
    this.args_ = args;
    this.suffix_ = suffix;
  }

  override string name() {
    return (super.name ~ "(" ~ args_.joiner(", ").text ~ ") " ~ suffix_.joiner(" ").text).strip;
  }

  string functionName() { return super.name; }

  // We do not look inside functions right now. Ignore.
  override Statement[] getStatements() { return Statement[].init; }

  bool isDeclaration() { return cast(NestedEntity)entities_[$-1] is null; }
}

Statement createStatement(Entity[] entities, string[string] info)
{
  switch (info["type"])
  {
    case "function":
      return new FunctionStatement(info["type"],
                                   info["name"],
                                   info["return"],
                                   info["args"].splitter(" , ").array,
                                   info["suffix"].splitter(" ").array,
                                   entities);
    default:
      return new Statement(info["type"], info["name"], entities);
  }
}

Statement createStatement(Entity[] entities)
{
  return createStatement(entities, getStatementType(entities));
}

Statement beginsStatement(Entity[] entities, Entity nextEntity)
{
  if (auto tokenEntity = cast(TokenEntity)nextEntity)
  {
    if (tokenEntity.type is tk!"namespace" ||
        tokenEntity.type is tk!"class" ||
        tokenEntity.type is tk!"struct" ||
        tokenEntity.type is tk!"enum" ||
        tokenEntity.type is tk!"union"
        )
    {
      return createStatement(entities);
    }
  }
  return null;
}

Statement endsStatement(Entity[] entities)
{
  if (!entities.empty)
  {
    if (auto tokenEntity = cast(TokenEntity)entities.back)
    {
      // all proper statements
      if (tokenEntity.type is tk!";")
      {
        return createStatement(entities);
      }
      // strip labels
      if (tokenEntity.type is tk!":" && entities.length == 2)
      {
        return createStatement(entities);
      }
    }
    // find "statements" that end with a nested entity
    auto firstToken = cast(TokenEntity)entities.front;
    if (firstToken)
    {
      if (auto lastToken = cast(NestedEntity)entities.back)
      {
        auto info = getStatementType(entities);
        if (info["type"] == "namespace" || info["type"] == "function")
        {
          return createStatement(entities, info);
        }
      }
    }
  }
  return null;
}

Statement[] splitStatements(Entity[] entities)
{
  Statement[] statements;
  ulong start = 0;
  for (ulong i = 0; i < entities.length; i++)
  {
    auto e = entities[i];
    if (start < i)
    {
      if (auto statement = beginsStatement(entities[start .. i], e))
      {
        statements ~= statement;
        start = i;
        continue;
      }
    }
    if (auto statement = endsStatement(entities[start .. i+1]))
    {
      statements ~= statement;
      start = i + 1;
      continue;
    }
  }
  if (start < entities.length)
  {
    statements ~= createStatement(entities[start .. $]);
  }
  return statements;
}

void printStatements(Statement[] statements, string indent)
{
  foreach(s; statements) {
    writeln(indent, s.type, ": ", s.name);
    // if (s.type == "code") {
    //   s.print(stdout);
    //   writeln;
    // }
    printStatements(s.getStatements(), indent ~ "    ");
  }
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

Statement[] readStatements(string filename)
{
  auto content = filename.readInput;
  return readStatements(content, filename);
}

Statement[] readStatements(string content, string filename)
{
  auto tokens = content.tokenize(filename);
  auto entities = createEntities(tokens);
  auto statements = splitStatements(entities);
  return statements;
}

void writeStatements(File f, Statement[] statements)
{
  foreach(s; statements) {
    s.print(f);
  }
}

Statement merge(Statement lhs, Statement rhs)
{
  switch (lhs.type)
  {
    case "code":
      return new Statement(lhs.type, lhs.name, lhs.entities ~ rhs.entities);
    case "namespace":
      if (auto nested = cast(NestedEntity)lhs.entities.back)
      {
        // too much knowledge here
        auto statements = merge(lhs.getStatements(), rhs.getStatements());
        auto entities = statements.map!(s => s.entities).joiner.array;
        return new Statement(lhs.type, lhs.name,
                             lhs.entities[0 .. $-1] ~ [nested.entities.front] ~ entities ~ [nested.entities.back]);
      }
      else
      {
        // there could be something
        return rhs;
      }
    default:
      return lhs;
  }
}

Statement[] merge(Statement[] lhs, Statement[] rhs)
{
  Statement[] result;
  Statement[string] functions;
  void appendStatement(Statement s) {
    if (s.type == "function")
    {
      auto name = s.name;
      if (name !in functions)
      {
        result ~= s;
      }
      functions[name] = s;
    }
    else
    {
      result ~= s;
    }
  }
  for (;;)
  {
    if (lhs.empty)
    {
      foreach (s; rhs) appendStatement(s);
      return result;
    }
    if (rhs.empty)
    {
      foreach (s; lhs) appendStatement(s);
      return result;
    }

    if (lhs.front.type == rhs.front.type &&
        lhs.front.name == rhs.front.name)
    {
      result ~= merge(lhs.front, rhs.front);
      lhs.popFront;
      rhs.popFront;
    }
    else
    {
      appendStatement(lhs.front);
      lhs.popFront;
    }
  }
}

void merge(File f, string filename1, string filename2)
{
  auto lhs = readStatements(filename1);
  auto rhs = readStatements(filename2);
  auto combined = merge(lhs, rhs);
  writeStatements(f, combined);
}
