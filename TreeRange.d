import std.array, std.algorithm, std.range;

// Walk a nested (tree) structure "depth-first". Return the path from root to
// leaf in each step.

auto treeRange(alias isBranch, alias children, T)(T[] root)
{
  struct Walker
  {
	this(T[] nodes)
	{
	  nodes_ = nodes;
	}
	bool empty() { return nodes_.empty && stack_.empty; }
	T[] front() { return stack_.filter!(e => !e.empty).map!(e => e.front).array ~ nodes_.front; }
	Walker save() { return this; }
	void popFront()
	{
	  if (!nodes_.empty)
	  {
		auto f = nodes_.front;
		if (isBranch(f))
		{
		  stack_ ~= nodes_;
		  nodes_ = children(f);
		}
		else
		{
		  nodes_ = nodes_[1 .. $];
		}
	  }
	  while (nodes_.empty && !stack_.empty)
	  {
		nodes_ = stack_.back()[1 .. $];
		stack_.popBack();
	  }
	}

	T[] nodes_;
	T[][] stack_;
  }

  return Walker(root);
}

unittest
{
  import std.stdio, std.conv;
  class Node
  {
	this(int payload, Node[] children) {
	  this.payload = payload;
	  this.children = children;
	}
	int payload;
	Node[] children;
  }
  auto nodes = [new Node(1, [new Node(2, [new Node(3, [])]),
							 new Node(4, [new Node(5, [new Node(6, [])])]),
							 new Node(7, [])
							 ])
				];

  auto r = treeRange!(t => !t.children.empty, t => t.children)(nodes);
  foreach (e; r) {
	writeln(e.map!(i => to!string(i.payload)).joiner("-"));
  }
}
