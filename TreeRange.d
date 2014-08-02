import std.array, std.algorithm, std.range;

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
		  auto n = children(f);
		  stack_ ~= nodes_;
		  nodes_ = n;
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
