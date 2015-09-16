import std.algorithm, std.array, std.range, std.file, std.stdio, std.exception, std.conv, std.typecons;

import Scanner;
import TreeRange;
import Tokenizer;
import TokenRange;

auto mergedRange(Token[][] tokensList)
{
  struct Result
  {
    this(Token[][] tokensList)
    {
      tokenRanges_ = tokensList.map!(f => f.namespaceTokenRange).array;
      rangeState_.length = tokenRanges_.length;
      for (auto i=0; i<rangeState_.length; ++i) {
        nextState(i);
      }
      pos_ = 0;
      prependNewline_ = false;
    }

    bool empty() { return tokenRanges_.map!(r => r.empty).reduce!((e, v) => v && e); }
    Token front()
    {
      if (prependNewline_)
      {
        auto t = tokenRanges_[pos_].front;
        t.token_.precedingWhitespace_ = "\n" ~ t.token_.precedingWhitespace_;
        return t.token_;
      }
      else
      {
        return tokenRanges_[pos_].front.token_;
      }
    }

    Result save() { return this; }

    private void nextPosition()
    {
      // If this token range (to this entity) is empty, switch to the next
      // token range on the same namespace level.
      if (!empty)
      {
        for (; tokenRanges_[pos_].empty; pos_ = (pos_+1) % tokenRanges_.length)
        {
        }
      }
    }

    private void nextState(ulong pos)
    {
      rangeState_[pos] = RangeState();
      if (!tokenRanges_[pos].empty)
      {
        auto t = tokenRanges_[pos].front;
        if (t.entity_)
        {
          if (t.entity_.type_ == "namespace")
          {
            if (t.token_.value == "namespace")
            {
              rangeState_[pos] = RangeState(t.entity_.name, "enter");
            }
            else if (t.token_.value == "}")
            {
              rangeState_[pos] = RangeState(t.entity_.name, "exit");
            }
          }
        }
      }
    }

    void popFront()
    {
      prependNewline_ = false;
      if (!tokenRanges_[pos_].empty)
      {
        tokenRanges_[pos_].popFront;
      }
      nextPosition();
      if (!tokenRanges_[pos_].empty)
      {
        nextState(pos_);
        if (!rangeState_[pos_].name.empty)
        {
          // Cycle over the states of all inputs. We want to find the next
          // normal input and slice it in.
          // Make sure to always use the input in given order.
          auto states = iota(rangeState_.length)
            .zip(rangeState_)
            // .cycle(pos_+1)
            // .take(rangeState_.length)
            .array;
          //std.stdio.writeln(states);
          auto p = states.find!(t => t[1].name.empty);
          if (!p.empty)
          {
            pos_ = p.front[0];
            prependNewline_ = true;
            nextPosition();
          }
          else
          {
            // no normal token waiting any longer
            // if there is some namespace to enter, do so
            p = states.find!(t => t[1].action == "enter");
            if (!p.empty)
            {
              pos_ = p.front[0];
              auto name = p.front[1].name;
              namespaceStack_ ~= name;

              // enhance all other inputs that are waiting at the same namespace
              foreach (e; states)
              {
                if (e[0] != pos_ && e[1].name == name && e[1].action == "enter" && !tokenRanges_[e[0]].empty)
                {
                  tokenRanges_[e[0]].popFront;
                  // consume the start of the namespace tokens, so we output
                  // them only once
                  while (!tokenRanges_[e[0]].empty)
                  {
                    auto value = tokenRanges_[e[0]].front.token_.value;
                    auto done = value == "{" || value == ";";
                    tokenRanges_[e[0]].popFront;
                    if (done)
                      break;
                  }
                  nextState(e[0]);
                }
              }
            }
            else
            {
              // no namespace to enter any more, we need to get out of the namespace
              auto name = namespaceStack_[$-1];
              namespaceStack_.popBack;
              p = states.find!(t => t[1].name == name && t[1].action == "exit");
              if (p.empty)
              {
                throw new Exception("Missing closing token for namespace '" ~ name ~ "'");
              }
              pos_ = p.front[0];

              // consume the namespace closings that are not needed
              foreach (e; states)
              {
                if (e[0] != pos_ && e[1].name == name && e[1].action == "exit" && !tokenRanges_[e[0]].empty)
                {
                  tokenRanges_[e[0]].popFront;
                  nextState(e[0]);
                }
              }
            }
          }
        }
      }
    }

    TokenRangeResult[] tokenRanges_;
    alias RangeState = Tuple!(string, "name", string, "action");
    RangeState[] rangeState_;
    string[] namespaceStack_;
    ulong pos_;
    bool prependNewline_;
  }

  return Result(tokensList);
}

auto mergedRange(string[] filenames)
{
  auto tokensList = filenames.map!(f => f.readInput.tokenize(f)).array;
  return mergedRange(tokensList);
}
