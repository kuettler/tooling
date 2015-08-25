import std.functional : unaryFun, binaryFun;
import std.range;
import std.traits;
import std.typecons : tuple, Tuple;
import std.typetuple : TypeTuple, staticMap, allSatisfy;

import std.algorithm;
import std.array;
import std.stdio;
import Tokenizer;

auto mySplitter(alias pred = "a == b", Range, Separator)(Range r, Separator s)
if (((hasSlicing!Range && hasLength!Range) || isNarrowString!Range)
	&& is (typeof(binaryFun!pred(r.front, s)) : bool))
{
    import std.conv : unsigned;

    static struct Result
    {
    private:
        Range _input;
        Separator _separator;
        // Do we need hasLength!Range? popFront uses _input.length...
        alias IndexType = typeof(unsigned(_input.length));
        enum IndexType _unComputed = IndexType.max - 1, _atEnd = IndexType.max;
        IndexType _frontLength = _unComputed;
        IndexType _backLength = _unComputed;

        static if (isNarrowString!Range)
        {
            size_t _separatorLength;
        }
        else
        {
            enum _separatorLength = 1;
        }

        static if (isBidirectionalRange!Range)
        {
            static IndexType lastIndexOf(Range haystack, Separator needle)
            {
                auto r = haystack.retro().find!pred(needle);
                return r.retro().length - 1;
            }
        }

    public:
        this(Range input, Separator separator)
        {
            _input = input;
            _separator = separator;

            static if (isNarrowString!Range)
            {
                import std.utf : codeLength;

                _separatorLength = codeLength!(ElementEncodingType!Range)(separator);
            }
            if (_input.empty)
                _frontLength = _atEnd;
        }

        static if (isInfinite!Range)
        {
            enum bool empty = false;
        }
        else
        {
            @property bool empty()
            {
                return _frontLength == _atEnd;
            }
        }

        @property Range front()
        {
            assert(!empty);
            if (_frontLength == _unComputed)
            {
                auto r = _input.find!pred(_separator);
                _frontLength = _input.length - r.length;
            }
            return _input[0 .. _frontLength];
        }

        void popFront()
        {
            assert(!empty);
            if (_frontLength == _unComputed)
            {
                front;
            }
            assert(_frontLength <= _input.length);
            if (_frontLength == _input.length)
            {
                // no more input and need to fetch => done
                _frontLength = _atEnd;

                // Probably don't need this, but just for consistency:
                _backLength = _atEnd;
            }
            else
            {
                _input = _input[_frontLength + _separatorLength .. _input.length];
                _frontLength = _unComputed;
            }
        }

        static if (isForwardRange!Range)
        {
            @property typeof(this) save()
            {
                auto ret = this;
                ret._input = _input.save;
                return ret;
            }
        }

        static if (isBidirectionalRange!Range)
        {
            @property Range back()
            {
                assert(!empty);
                if (_backLength == _unComputed)
                {
                    immutable lastIndex = lastIndexOf(_input, _separator);
                    if (lastIndex == -1)
                    {
                        _backLength = _input.length;
                    }
                    else
                    {
                        _backLength = _input.length - lastIndex - 1;
                    }
                }
                return _input[_input.length - _backLength .. _input.length];
            }

            void popBack()
            {
                assert(!empty);
                if (_backLength == _unComputed)
                {
                    // evaluate back to make sure it's computed
                    back;
                }
                assert(_backLength <= _input.length);
                if (_backLength == _input.length)
                {
                    // no more input and need to fetch => done
                    _frontLength = _atEnd;
                    _backLength = _atEnd;
                }
                else
                {
                    _input = _input[0 .. _input.length - _backLength - _separatorLength];
                    _backLength = _unComputed;
                }
            }
        }
    }

    return Result(r, s);
}

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

  auto assignment = tokens.mySplitter!"a.type_ == b"(tk!"=");
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

void testRun()
{
  auto definitions =
	[
	 "    Fee::TransactionBasedFeeRulePtr newRule = new Fee::TransactionBasedFeeRule;",
	 "    amount += info.amount;",
	 "    info.amount = 17;",
	 "    amount = 17;",
	 "    SearchStruct search;",
	 "    Ice::Long a;",
	 "    Ice::Long a = 0;",
	 "    std::string feeTypeStr = \"unknown\";",
	 "    std::string feeTypeStr = props.getString(\"feeType\");",
	 "    Fee::ProductFeeType feeType = Fee::StringToProductFeeType(feeTypeStr);",
	 "    double quantity = props.getDouble(\"feeQuantity\");",
	 "    Ice::Long amount = feeRulesSet->getActionBasedFeeAmount(feeType);",
	 "    auto gps = makeFactoryProxy<CardProcessor::Gps>(RMG_CUR_POS, current);",
	 "    auto processor = makeFactoryProxy<Finance::PaymentCardProcessor>(RMG_CUR_POS, current);",
	 "    auto factory = makeFactoryProxy<Finance::TransactionFactory>(RMG_CUR_POS, current);",
	 "    static Rmg::Util::MappedLock<std::string>::LockMap lockMap;",
	 "    std::shared_ptr<xercesc::XercesDOMParser> parser(new xercesc::XercesDOMParser());",
	 ];
  foreach (ref d; definitions) {
	auto tokens = tokenize(d, "<inline>");

	// odd final token
	tokens = tokens[0 .. $-1];

	auto result = convertStatement(tokens);

	foreach (t; result[0 .. $-1]) {
	  write(t.precedingWhitespace_, t.value);
	}
	writeln();
  }
}

void main()
{
  testRun();
}
