import std.stdio;
import Scanner : readInput, scanTokens;

void main()
{
  auto filename = "TestFile.cpp";
  auto tokens = filename.readInput.tokenize(filename);
  auto content = scanTokens(tokens);
  foreach (pos; [[259,14], [912,29]])
  {
    foreach (e; content)
    {
      auto found = e.findAt(pos[0], pos[1]);
      if (found.length)
      {
        foreach (f; found)
        {
          writeln(f.type_, ": ", f.name);
        }
        break;
      }
    }
    writeln();
  }
}
