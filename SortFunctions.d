import std.algorithm, std.array, std.file, std.stdio, std.exception, std.conv;

import Scanner;
import TreeRange;
import Tokenizer;
import TokenRange;

void main(string[] args)
{
  enforce(args.length > 1,
          text("Usage:", args[0], " files..."));

  foreach (fi; 1 .. args.length)
  {
    auto filename = args[fi];
	auto sourceFile = SourceFile(filename);

	auto newFile = filename ~ ".tmp";
    auto f = File(newFile, "w");

	Entity[string][] entityStack;
	foreach (ref t; sourceFile.tokenRange)
	{
	  if (t.token_.type_ == tk!"\0")
	  {
		f.write(t.token_.precedingWhitespace_);
	  }
	  else if (!t.entity_)
	  {
		f.write(t.token_.precedingWhitespace_, t.token_.value);
	  }
	  else if (t.entity_.type_ == "namespace")
	  {
		if (t.token_.value == "{")
		{
		  entityStack.length += 1;
		}
		else if (t.token_.value == "}")
		{
		  foreach (name; entityStack.back.keys.array.sort)
		  {
			auto e = entityStack.back[name];
			foreach (et; e.tokens_)
			{
			  f.write(et.precedingWhitespace_, et.value);
			}
		  }
		  entityStack.popBack;
		}
		f.write(t.token_.precedingWhitespace_, t.token_.value);
	  }
	  else if (t.entity_.type_ == "function")
	  {
		if (t.entity_.name !in entityStack.back)
		{
		  entityStack.back[t.entity_.name] = t.entity_;
		}
	  }
	  else
	  {
		f.write(t.token_.precedingWhitespace_, t.token_.value);
	  }
	}
    f.close;
    std.file.rename(newFile, filename);
  }
}
