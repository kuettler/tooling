import std.stdio;
import Scanner : readTokens, scanTokens;

void main()
{
  auto tokens = readTokens("/home/ukuettler/projects/xcard-base/MediatorCardLoading/MediatorCardLoadingFunctions.cpp");
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
