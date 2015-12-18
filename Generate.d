import std.algorithm;
import std.array;
import std.conv;

import Statement : NestedEntity, Statement, FunctionStatement;

// Implement the cpp file to a given header

string createNamespace(Statement statement, string indent)
{
  return (indent ~ "namespace " ~ statement.name ~ "\n" ~
          indent ~ "{\n" ~
          createCxxFileContent(statement.getStatements, indent ~ "\t", []) ~
          indent ~ "}\n"
    );
}

string createClass(Statement statement, string indent, string[] classStack)
{
  return createCxxFileContent(statement.getStatements, indent, classStack ~ statement.name);
}

string createFunction(FunctionStatement statement, string indent, string[] classStack, NestedEntity functionBody)
{
  auto className = classStack.joiner("::").to!string;
  if (className) className ~= "::";
  bool headerOnly(string name) {
    return !find(["explicit", "static", "override", "virtual", "friend"], name).empty;
  }
  auto entities = statement.entities[0 .. $-1].filter!(t => !headerOnly(t.value)).array;
  string result;
  if (entities) {
    result ~= indent;
    bool classNameInserted = false;
    // constructor or destructor
    if (entities[0].value == "~" || entities[0].value == statement.name) {
      result ~= className;
      classNameInserted = true;
    }
    result ~= entities[0].value;
    foreach (t; entities[1 .. $]) {
      if (!classNameInserted && (t.value == "~" || t.value == statement.functionName)) {
        result ~= t.precedingWhitespace ~ className ~ t.value;
        classNameInserted = true;
      }
      else {
        result ~= t.precedingWhitespace ~ t.value;
      }
    }
    if (functionBody) {
      result ~= functionBody.valueString ~ "\n";
    }
    else {
      result ~= "\n" ~
                indent ~ "{\n" ~
                indent ~ "\t// FIXME: Implementation missing\n" ~
                indent ~ "}\n\n";
    }
  }
  return result;
}

string createCxxFileContent(Statement[] statements, string indent, string[] classStack)
{
  string result;
  foreach (s; statements) {
    switch (s.type) {
      case "namespace":
        result ~= createNamespace(s, indent);
        break;
      case "class":
        result ~= createClass(s, indent, classStack);
        break;
      case "function":
        if (auto f = cast(FunctionStatement)s)
        {
          result ~= createFunction(f, indent, classStack, f.getFunctionBody);
        }
        break;
      default:
        break;
    }
  }
  return result;
}
