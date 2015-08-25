import std.algorithm;
import std.array;
import std.file : readText;
import std.functional : unaryFun, binaryFun;
import std.range;
import std.stdio;
import std.traits;
import std.typecons : tuple, Tuple;
import std.typetuple : TypeTuple, staticMap, allSatisfy;

import Tokenizer : Token, tokenize, tk;

void outputVariable(ref string app, Token[] tokens, bool outputType=true)
{
    auto name = tokens[$-1];
    swap(name.precedingWhitespace_, tokens[0].precedingWhitespace_);
    app ~= name.precedingWhitespace_;
    app ~= "auto ";
    app ~= name.value;
    app ~= " =";
    if (outputType) {
	foreach (ref t; tokens[0 .. $-1]) {
            app ~= t.precedingWhitespace_;
            app ~= t.value;
	}
    }
}

Token[] convertStatement(Token[] tokens)
{
    if (tokens[0].type_ == tk!"auto" ||
        tokens[0].type_ == tk!"return" ||
        tokens[0].type_ == tk!"case" ||
        tokens[0].type_ == tk!"default"
        )
        return tokens;

    //auto app = appender!string();
    auto app = "";

    auto assignment = tokens.splitter!"a.type_ == b"(tk!"=");
    auto variable = assignment.front;
    assignment.popFront;

    if (assignment.empty) {
        variable = variable[0 .. $-1];
    }

    if (variable[0].type_ == tk!"static") {
        app ~= variable[0].precedingWhitespace_;
        app ~= variable[0].value;
        variable = variable[1 .. $];
        variable[0].precedingWhitespace_ = " ";
    }

    foreach (ref t; variable[0 .. $-1]) {
	if (t.type_ != tk!"identifier" &&
            t.type_ != tk!"const" &&
            t.type_ != tk!"int" &&
            t.type_ != tk!"double" &&
            t.type_ != tk!"float" &&
            t.type_ != tk!"long" &&
            t.type_ != tk!"::" &&
            t.type_ != tk!"*" &&
            t.type_ != tk!"&" &&
            t.type_ != tk!"," &&
            t.type_ != tk!"<" &&
            t.type_ != tk!">"
            )
	{
            //writeln(t.type_, t.type_.sym);
            return tokens;
	}
    }

    if (variable.length == 1)
	return tokens;
    if (variable[$-1].type_ != tk!"identifier")
	return tokens;

    if (!assignment.empty) {
	bool outputType = true;
	auto value = assignment.front[0 .. $-1].array;
	if ((value.length == 1 &&
             (value[0].type_ != tk!"string_literal" ||
              value[0].type_ != tk!"number")) ||
            variable[$-2].value.endsWith("Ptr"))
	{
            value[0].precedingWhitespace_ = "";
	}
	else if (value.length >= 1)
	{
            value[0].precedingWhitespace_ = "";
            outputType = false;
	}

	outputVariable(app, variable, outputType);
	app ~= (outputType ? "{" : " ");
	foreach (ref t; value) {
            app ~= t.precedingWhitespace_;
            app ~= t.value;
	}
	app ~= (outputType ? "};" : ";");
    } else {
	outputVariable(app, variable);
	app ~= ("{};");
    }

    return tokenize(app)[0 .. $-1];
}

alias StatementToken = Tuple!(Token[], "tokens_", bool, "isStatement_");

string value(ref Token t)
{
    if (t.type_ is tk!"identifier")
	return t.value_;
    else
	return t.type_.sym;
}

struct StatementRange
{
    bool empty() { return tokens_.length <= begin_; }
    StatementToken front() { return StatementToken(tokens_[begin_ .. end_], isStatement_); }
    void popFront()
    {
	begin_ = end_;
	isStatement_ = true;
	while (tokens_.length > end_) {
            end_ += 1;
            switch (value(tokens_[end_-1])) {
            case "{":
            case "}":
		isStatement_ = false;
            return;
            case ";":
		if (begin_ == end_-1) {
                    isStatement_ = false;
		}
		return;
            default:
		break;
            }
	}
    }

    Token[] tokens_;
    size_t begin_;
    size_t end_;
    bool isStatement_;
}

void writeTokens(Token[] tokens)
{
    foreach (ref t; tokens) {
	write(t.precedingWhitespace_, t.value);
    }
}

void main(string[] args)
{
    string content;
    foreach (ulong i, string line; lines(stdin))
    {
	content ~= line;
    }

    auto tokens = tokenize(content);
    foreach (stmt; StatementRange(tokens[0 .. $-1])) {
	if (stmt.isStatement_) {
            writeTokens(convertStatement(stmt.tokens_));
	} else {
            writeTokens(stmt.tokens_);
	}
    }
    write(tokens[$-1].precedingWhitespace_);
}
