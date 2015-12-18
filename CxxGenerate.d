import std.stdio;

import Statement : readStatements, writeStatements;
import Generate : createCxxFileContent;

void main()
{
  write(createCxxFileContent(readStatements("-"), "", []));
}
