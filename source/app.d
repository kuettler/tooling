module tooling.app;

import std.stdio;

import tooling.CxxImplement;
import tooling.CxxMerge;
import tooling.CxxSortFunctions;

int main(string[] args)
{
  try
  {
	if (args.length > 1)
	{
	  switch (args[1])
	  {
		case "implement":
		  return implementMain(args);
		case "merge":
		  return mergeMain(args);
		case "sort":
		  return sortFunctionsMain(args);
		default:
		  break;
	  }
	}
  }
  catch (Exception e)
  {
	stderr.writeln(e.msg);
	return 1;
  }

  printHelp();
  return 0;
}

/**
 * Prints help message
 */
void printHelp()
{
  stdout.writeln(`
C++ tooling.

Usage:

    tooling cmd [options]

Commands:

    implement
        Given a C++ header/source file pair, add missing stub functions to the source file
    merge
        Merge any number of C++ files into one, preserving the namespace structure
    sort
        Sort C++ functions by name, preserving the namespace structure of the file

Options are command specific.
`);
}
