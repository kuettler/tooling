import std.algorithm : splitter, find, chunkBy, map, joiner, cmp, startsWith, endsWith, remove;
import std.array : Appender, array, replace;
import std.conv : text;
import std.file : readText;
import std.range : chain;
import std.range.primitives : save, empty, popFront, popBack, front, back;
import std.regex : regex, matchFirst;
import std.stdio : File, write, writeln, stdout, stdin, lines;
import std.string : strip;

import Tokenizer : tokenize, tk, Token, TokenType;
import TreeRange : treeRange;

class Entity
{
public:
  size_t position() const { return 0; }
  string precedingWhitespace() const { return ""; }
  string value() const { return ""; }
  string valueString() const { return ""; }
  void print(File f) {}
  void printSimple(File f) {}
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
  override size_t position() const { return t.position_; }
  override string precedingWhitespace() const { return t.precedingWhitespace_; }
  override string value() const { return t.value; }
  override string valueString() const { return t.precedingWhitespace_ ~ t.value; }
  override void print(File f) {
    if (type is tk!"\0")
    {
      //f.write(t.precedingWhitespace_);
    }
    else
    {
      f.write(t.precedingWhitespace_, t.value);
    }
  }
  override void printSimple(File f) {
    print(f);
  }
}

class NestedEntity : Entity
{
  Entity[] entities_;
public:
  this(Entity[] entities_) {
    this.entities_ = entities_;
  }

  override size_t position() const {
    foreach (e; entities_) {
      if (auto p = e.position)
      {
        return p;
      }
    }
    return 0_;
  }
  override string precedingWhitespace() const { return entities_.front.precedingWhitespace; }
  override string value() const { return "{ ... }"; }
  override string valueString() const {
    Appender!string app;
    foreach (e; entities_) {
      app.put(e.valueString());
    }
    return app.data;
  }
  override void print(File f) {
    entities_.front.print(f);
    foreach (s; getStatements()) {
      s.print(f);
    }
    entities_.back.print(f);
  }
  override void printSimple(File f) {
    foreach(e; entities_)
    {
      e.printSimple(f);
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

// auto functionRe = regex(r"(template <[^>]+> )?" ~
//                         r"(?P<return>([a-zA-Z0-9_&<,>* ]+|(::[a-zA-Z0-9_&<,>* ]+))+ )?" ~
//                         r"(?P<name>(((~ )|(:: ))?[a-zA-Z0-9_]+|( :: ))+)" ~
//                         r"(o?perator *.[^(]*)?" ~
//                         r" \( (?P<args>[a-zA-Z0-9_ :&<,>*]*)\)" ~
//                         r"(?P<suffix> [a-zA-Z]+)*"
//   );

auto functionRe = regex(r"(?P<template>template <[^>]+> )?" ~
                        r"(?P<virtual>virtual )?" ~
                        r"(?P<inline>inline )?" ~
                        r"(?P<return>[:a-zA-Z0-9_&<,>* ]*[a-zA-Z0-9_&>*] )?" ~
                        r"(?P<name>[~a-zA-Z_][:a-zA-Z0-9_ ]*.[^(]*)" ~
                        r" \( (?P<args>[a-zA-Z0-9_ :&<,>*.]*)\)" ~
                        r"(?P<suffix> [a-zA-Z]+)*"
  );

unittest
{
  auto content = q{
			namespace
			{
				template <class T>
				void throwErrorOrCollectNewStyle(bool isNewStyle,
				                                 std::set<std::string>& errorIdentifiers,
				                                 const std::string& errorCode,
				                                 const std::string& msg,
				                                 const std::string& pos,
				                                 const Ice::Current& current)
				{
					auto if (isNewStyle) ->
					{
						errorIdentifiers.insert(ApiUtil::getErrorIdentifier(errorCode));
					}
					else
					{
						throwWithError<T>(msg, pos, current);
					}
				}
			}
  };

  // auto tokens = content.tokenize("");
  // auto entities = createEntities(tokens);
  // auto line = entities.map!(e => e.value).joiner(" ").text;
  // auto m = line.matchFirst(functionRe);
  // foreach (n; ["args", "template", "return", "name", "suffix"])
  // {
  //   writeln(n, ": ", m[n]);
  // }

  auto statements = readStatements(content, "");
  writeStatements("-", statements);
  writeln();
}

string purgeWhitespace(string s)
{
  return s.replace(" ", "");
}

auto getStatementType(Entity[] entities)
{
  auto line = entities.map!(e => e.value).joiner(" ").text;
  auto m = line.matchFirst(structRe);
  if (!m.empty)
  {
    return ["type": m["type"], "name": m["name"].purgeWhitespace];
  }

  m = line.matchFirst(functionRe);
  if (!m.empty)
  {
    return ["type": "function",
            "name": m["name"].purgeWhitespace,
            "virtual" : m["virtual"],
            "inline" : m["inline"],
            "template": m["template"],
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
  Statement[] statements_;

public:
  this(string type, string name, Entity[] entities) {
    this.type_ = type;
    this.name_ = name;
    this.entities_ = entities;
    this.statements_ = entities_.map!(e => e.getStatements).joiner.array;
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

  size_t position() const {
    foreach (e; entities_) {
      if (auto p = e.position)
      {
        return p;
      }
    }
    return 0;
  }

  Statement[] getStatements() {
    return statements_;
  }
}

class FunctionStatement : Statement
{
private:
  string template_;
  string returnType_;
  string[] args_;
  string[] suffix_;
  string virtual;
  string inline;

public:
  this(string type, string templateStr, string virtual, string inline, string name, string returnType, string[] args, string[] suffix, Entity[] entities) {
    super(type, name, entities);
    this.template_ = templateStr;
    this.virtual = virtual;
    this.inline = inline;
    this.returnType_ = returnType;
    this.args_ = args;
    this.suffix_ = suffix;
  }

  // print functions auto style
override void print(File f) {
    if (returnType_ == "auto") {
      foreach (e; this.entities()) {
        e.printSimple(f);
      }
      return;
    }

    bool isTypeless = returnType_ == "";
    auto functionEntities = this.entities();

    f.write(functionEntities.front.precedingWhitespace, template_, inline, virtual, isTypeless ? "" : "auto ", super.name);
    while (functionEntities.front.value != "(")
    {
    functionEntities = functionEntities[1 .. $];
    }
    while (functionEntities.front.value != ")")
    {
    functionEntities.front.print(f);
    functionEntities = functionEntities[1 .. $];
    }
    functionEntities.front.print(f);
    functionEntities = functionEntities[1 .. $];

    bool endsWithSemicolon = endsWith(functionEntities.back.value, ";");
    bool functionDefined = false;
    bool pureVirtual = false;
    bool hasOverride = false;

    foreach (e; functionEntities) {
        if (!find(e.value, "{").empty) {
            functionDefined = true;
            break;
        }
    }

    if (!functionDefined){
        foreach(e; functionEntities) {
            if (e.value == "=" || e.value == "0") {
                pureVirtual = true;
            } else if (e.value == "override") {
                hasOverride = true;
            } else {
                f.write(replace(e.value, ";",""), " ");
            }
        }
        if (!isTypeless) {
            f.write(" -> ", returnType_);
        }
        if (pureVirtual) {
            f.write("= 0");
        }
        if (hasOverride) {
            f.write(" override");
        }
        if(endsWithSemicolon) {
            f.write(";");
        }
    } else {
        while (functionEntities.length && !functionEntities.front.value.startsWith("{")) {
            functionEntities.front.print(f);
            functionEntities = functionEntities[1..$];
        }
        if (!isTypeless) {
            f.write(" -> ", returnType_);
        }
        foreach(e; functionEntities) {
            e.printSimple(f);
        }
    }
}

  // override string name() {
  //   return (super.name ~ "(" ~ args_.joiner(", ").text ~ ") " ~ suffix_.joiner(" ").text).strip;
  // }

  string functionName() { return super.name; }

  // We do not look inside functions right now. Ignore.
  override Statement[] getStatements() { return Statement[].init; }

  NestedEntity getFunctionBody() { return cast(NestedEntity)entities_[$-1]; }
  bool isDeclaration() { return getFunctionBody() is null; }
}

auto walk(Statement[] statements)
{
  return treeRange!(t => !t.getStatements().empty,
                    t => t.getStatements())(statements);
}

Statement createStatement(Entity[] entities, string[string] info)
{
  switch (info["type"])
  {
    case "function":
      return new FunctionStatement(info["type"],
                                   info["template"],
                                   info["virtual"],
                                   info["inline"],
                                   info["name"],
                                   info["return"],
                                   info["args"].splitter(" , ").array,
                                   info["suffix"].splitter(" ").array,
                                   entities);
    case "namespace":
      if (info["name"].empty)
      {
        return new Statement(info["type"], "<anonymous>", entities);
      }
      return new Statement(info["type"], info["name"], entities);
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
      auto prevValue = entities[i-1].value;
      if (prevValue != "<" && prevValue != ",")
      {
        if (auto statement = beginsStatement(entities[start .. i], e))
        {
          statements ~= statement;
          start = i;
          continue;
        }
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

void writeStatements(string name, Statement[] statements)
{
  if (name == "-")
  {
    writeStatements(stdout, statements);
  }
  else
  {
    writeStatements(File(name, "w"), statements);
  }
}

void writeStatements(File f, Statement[] statements)
{
  foreach(s; statements) {
    s.print(f);
  }
  f.writeln();
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
