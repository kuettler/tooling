import std.algorithm, std.array, std.file, std.stdio, std.exception, std.conv, std.regex;
import Scanner;

void main(string[] args)
{
  enforce(args.length > 1,
          text("Usage:", args[0], " files..."));

  foreach (fi; 1 .. args.length)
  {
    auto headerfilename = args[fi];
	auto sourcefilename = headerfilename.replaceFirst(regex(r"\.h$"), ".cpp");

	auto headerfile = SourceFile(headerfilename);
	if (sourcefilename.exists)
	{
	  writeln("We have a source file");
	}
	else
	{
	  writeln("All new here");
	  foreach (e; headerfile.content_)
	  {
		e.print;
	  }
	}
  }
}
