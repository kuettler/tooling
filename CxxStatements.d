import std.array;
import std.file : readText;
import std.stdio;
import std.typecons;

import Tokenizer;

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

void printStatements(string filename)
{
    auto tokens = tokenize(readText(filename), filename);
    foreach (statement; StatementRange(tokens[0 .. $-1])) {
	if (statement.isStatement_) {
            write("'");
            foreach (ref t; statement.tokens_) {
		write(t.precedingWhitespace_, t.value);
            }
            writeln("'");
	}
    }
}

void main(string[] args)
{
    printStatements("/home/ukuettler/projects/xcard-base/FinanceService/TransactionFactoryI.cpp");
}
