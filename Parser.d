// based on ebrowse.c from emacs 24.5.1
/* ebrowse.c --- parsing files for the ebrowse C++ browser

Copyright (C) 1992-2017 Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.  */

import core.stdc.stddef;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.ctype;

import std.algorithm.comparison : max;
import std.algorithm.iteration : splitter;
import std.algorithm.searching;
import std.array;
import std.ascii;
import std.exception : ErrnoException;
import std.file : exists, readText;
import std.getopt;
import std.path : pathSeparator;
import std.range : assumeSorted;
import std.stdio;
import std.string;

import Tokenizer : Token, TokenType, tk, tokenize;

// Storage classes, in a wider sense.

enum sc
  {
    SC_UNKNOWN,
    SC_MEMBER,			// Is an instance member.
    SC_STATIC,			// Is static member.
    SC_FRIEND,			// Is friend function.
    SC_TYPE			// Is a type definition.
  };

// Member visibility.

enum visibility
  {
    V_PUBLIC,
    V_PROTECTED,
    V_PRIVATE
  };

// Member flags.

enum F_VIRTUAL	= 1;	// Is virtual function.
enum F_INLINE	= 2;	// Is inline function.
enum F_CONST		= 4;	// Is const.
enum F_PURE		= 8;	// Is pure virtual function.
enum F_MUTABLE	= 16;	// Is mutable.
enum F_TEMPLATE	= 32;	// Is a template.
enum F_EXPLICIT	= 64;	// Is explicit constructor.
enum F_THROW		= 128;	// Has a throw specification.
enum F_EXTERNC	= 256;	// Is declared extern "C".
enum F_DEFINE	= 512;	// Is a #define.

// Set and test a bit in an int.

static void
set_flag (int *f, int flag)
{
  *f |= flag;
}

static bool
has_flag (int f, int flag)
{
  return (f & flag) != 0;
}

// The name of the current input file.

string filename;

// Command line flags.

bool f_append;
bool f_verbose;
bool f_very_verbose;
bool f_structs = true;
bool f_regexps = true;
bool f_nested_classes = true;

// Structure describing a class member.

class member
{
  //member next;		// Next in list of members.
  member[]* list;		// Pointer to list in class.
  uint param_hash;		// Hash value for parameter types.
  int vis;			// Visibility (public, ...).
  int flags;			// See F_* above.
  string regexp;			// Matching regular expression.
  string filename;		// Don't free this shared string.
  long pos;			// Buffer position of occurrence.
  string def_regexp;		// Regular expression matching definition.
  string def_filename;	// File name of definition.
  long def_pos;			// Buffer position of definition.
  string name; // Member name.

  void print() {
    writeln(name, " : ", pos, " ", def_pos);
  }
}

// Structure used to record namespace aliases.

class ns_alias
{
  sym namesp;		// Namespace in which defined.
  sym[] aliasee;		// List of aliased namespaces (A::B::C...).
  string name; // Alias name.
}

// The structure used to describe a class in the symbol table,
// or a namespace in all_namespaces.

class sym
{
  int flags;			// Is class a template class?.
  byte visited;	// Used to find circles.
  sym[] subs;		// List of subclasses.
  sym[] supers;		// List of superclasses.
  member[] vars;		// List of instance variables.
  member[] fns;		// List of instance functions.
  member[] static_vars;	// List of static variables.
  member[] static_fns;	// List of static functions.
  member[] friends;	// List of friend functions.
  member[] types;		// List of local types.
  string regexp;			// Matching regular expression.
  long pos;			// Buffer position.
  string filename;		// File in which it can be found.
  string sfilename; 	// File in which members can be found.
  sym namesp;		// Namespace in which defined. .
  string name; // Name of the class.

  string getNamespace() {
    if (namesp !is null && !namesp.name.empty)
      return namesp.getNamespace() ~ namesp.name ~ "::";
    else
      return "";
  }

  void printMember(member e) {
    write("    ", getNamespace, name, "::");
    e.print;
  }

  void print() {
    writeln(getNamespace, name, " : ", pos, " ", flags);
    writeln("vars:"); foreach (e; vars) printMember(e);
    writeln("fns:"); foreach (e; fns) printMember(e);
    writeln("static_vars:"); foreach (e; static_vars) printMember(e);
    writeln("static_fns:"); foreach (e; static_fns) printMember(e);
    writeln("friends:"); foreach (e; friends) printMember(e);
    writeln("types:"); foreach (e; types) printMember(e);
  }
}

// Experimental: Print info for `--position-info'.  We print
// '(CLASS-NAME SCOPE MEMBER-NAME).

enum P_DEFN = 1;
enum P_DECL = 2;

int info_where;
sym info_cls = null;
member info_member = null;

Token[] tokens;

// The table for class symbols.

sym[][string] class_table;

// Table containing all member structures.  This is generally
// faster for member lookup than traversing the member lists of a
// `struct sym'.

member[][string] member_table;

// Table for namespace aliases

ns_alias[][string] namespace_alias_table;

// The special class symbol used to hold global functions,
// variables etc.

//sym global_symbols;

// The current namespace.

sym current_namespace;

// The list of all known namespaces.

sym[] all_namespaces;

// Stack of namespaces we're currently nested in, during the parse.

sym[] namespace_stack;

// Value is the string from the start of the line to the current
// position in the input buffer, or maybe a bit more if that string is
// shorter than min_regexp.

string matching_regexp() { return ""; }


//**********************************************************************
//			       Symbols
//**********************************************************************

// Add a symbol for class NAME to the symbol table.  NESTED_IN_CLASS
// is the class in which class NAME was found.  If it is null,
// this means the scope of NAME is the current namespace.
//
// If a symbol for NAME already exists, return that.  Otherwise
// create a new symbol and set it to default values.

static sym
add_sym (string name, sym nested_in_class)
{
  sym sym_ = null;
  sym scope_ = nested_in_class ? nested_in_class : current_namespace;

  if (name in class_table)
  {
    foreach (s; class_table[name])
    {
      if ((!s.namesp && !scope_) || (s.namesp && scope_ && s.namesp.name == scope_.name))
      {
        sym_ = s;
        break;
      }
    }
  }

  if (sym_ is null)
  {
    sym_ = new sym;
    sym_.name = name;
    sym_.namesp = scope_;
    class_table[name] ~= sym_;
  }

  return sym_;
}


// Add links between superclass SUPER and subclass SUB.

static void
add_link (sym super_, sym sub)
{
  auto r = assumeSorted!((a,b) => a.name < b.name)(super_.subs).trisect(sub);

  // See if a link already exists.
  if (!r[1].empty)
  {
    return;
  }

  // Avoid duplicates.
  super_.subs.insertInPlace(r[0].length, sub);
  sub.supers ~= super_;
}


// Find in class CLS member NAME.

// VAR non-zero means look for a member variable; otherwise a function
// is searched.  SC specifies what kind of member is searched---a
// static, or per-instance member etc.  HASH is a hash code for the
// parameter types of functions.  Value is a pointer to the member
// found or null if not found.

static member
find_member (sym cls, string name, int var, sc sc_, uint hash)
{
  member[]* list;
  int i;

  switch (sc_)
  {
    case sc.SC_FRIEND:
      list = &cls.friends;
      break;

    case sc.SC_TYPE:
      list = &cls.types;
      break;

    case sc.SC_STATIC:
      list = var ? &cls.static_vars : &cls.static_fns;
      break;

    default:
      list = var ? &cls.vars : &cls.fns;
      break;
  }

  if (name in member_table)
  {
    foreach (p; member_table[name])
    {
      if (p.list == list && p.param_hash == hash)
        return p;
    }
  }

  return null;
}


// Add to class CLS information for the declaration of member NAME.
// REGEXP is a regexp matching the declaration, if non-null.  POS is
// the position in the source where the declaration is found.  HASH is
// a hash code for the parameter list of the member, if it's a
// function.  VAR non-zero means member is a variable or type.  SC
// specifies the type of member (instance member, static, ...).  VIS
// is the member's visibility (public, protected, private).  FLAGS is
// a bit set giving additional information about the member (see the
// F_* defines).

static void
add_member_decl (sym cls, string name, string regexp, long pos, uint hash, int var, sc sc_, TokenType vis, int flags)
{
  member m;

  m = find_member (cls, name, var, sc_, hash);
  if (m is null)
    m = add_member (cls, name, var, sc_, hash);

  // Have we seen a new filename?  If so record that.
  if (!cls.filename || cls.filename != filename)
    m.filename = filename;

  m.regexp = regexp;
  m.pos = pos;
  m.flags = flags;

  switch (vis.id)
  {
    case tk!"private".id:
      m.vis = visibility.V_PRIVATE;
      break;

    case tk!"protected".id:
      m.vis = visibility.V_PROTECTED;
      break;

    case tk!"public".id:
      m.vis = visibility.V_PUBLIC;
      break;

    default:
      break;
  }

  info_where = P_DECL;
  info_cls = cls;
  info_member = m;
}


// Add to class CLS information for the definition of member NAME.
// REGEXP is a regexp matching the declaration, if non-null.  POS is
// the position in the source where the declaration is found.  HASH is
// a hash code for the parameter list of the member, if it's a
// function.  VAR non-zero means member is a variable or type.  SC
// specifies the type of member (instance member, static, ...).  VIS
// is the member's visibility (public, protected, private).  FLAGS is
// a bit set giving additional information about the member (see the
// F_* defines).

static void
add_member_defn (sym cls, string name, string regexp, long pos, uint hash, int var, sc sc_, int flags)
{
  member m;

  if (sc_ == sc.SC_UNKNOWN)
  {
    m = find_member (cls, name, var, sc.SC_MEMBER, hash);
    if (m is null)
    {
      m = find_member (cls, name, var, sc.SC_STATIC, hash);
      if (m is null)
        m = add_member (cls, name, var, sc_, hash);
    }
  }
  else
  {
    m = find_member (cls, name, var, sc_, hash);
    if (m is null)
      m = add_member (cls, name, var, sc_, hash);
  }

  if (!cls.sfilename)
    cls.sfilename = filename;

  if (cls.sfilename != filename)
    m.def_filename = filename;

  m.def_regexp = regexp;
  m.def_pos = pos;
  m.flags |= flags;

  info_where = P_DEFN;
  info_cls = cls;
  info_member = m;
}


// Add a symbol for a define named NAME to the symbol table.
// REGEXP is a regular expression matching the define in the source,
// if it is non-null.  POS is the position in the file.

static void
add_define (string name, string regexp, long pos)
{
  add_global_defn (name, regexp, pos, 0, 1, sc.SC_FRIEND, F_DEFINE);
  add_global_decl (name, regexp, pos, 0, 1, sc.SC_FRIEND, F_DEFINE);
}


// Add information for the global definition of NAME.
// REGEXP is a regexp matching the declaration, if non-null.  POS is
// the position in the source where the declaration is found.  HASH is
// a hash code for the parameter list of the member, if it's a
// function.  VAR non-zero means member is a variable or type.  SC
// specifies the type of member (instance member, static, ...).  VIS
// is the member's visibility (public, protected, private).  FLAGS is
// a bit set giving additional information about the member (see the
// F_* defines).

static void
add_global_defn (string name, string regexp, long pos, uint hash, int var, sc sc_, int flags)
{
  int i;
  sym sym_;

  // Try to find out for which classes a function is a friend, and add
  // what we know about it to them.
  if (!var)
    foreach (class_name, class_list; class_table)
    {
      foreach (sym_; class_list)
      {
	if (sym_ != current_namespace && sym_.friends)
	  if (find_member (sym_, name, 0, sc.SC_FRIEND, hash))
	    add_member_defn (sym_, name, regexp, pos, hash, 0,
			     sc.SC_FRIEND, flags);
      }
    }

  // Add to global symbols.
  add_member_defn (current_namespace, name, regexp, pos, hash, var, sc_, flags);
}


// Add information for the global declaration of NAME.
// REGEXP is a regexp matching the declaration, if non-null.  POS is
// the position in the source where the declaration is found.  HASH is
// a hash code for the parameter list of the member, if it's a
// function.  VAR non-zero means member is a variable or type.  SC
// specifies the type of member (instance member, static, ...).  VIS
// is the member's visibility (public, protected, private).  FLAGS is
// a bit set giving additional information about the member (see the
// F_* defines).

static void
add_global_decl (string name, string regexp, long pos, uint hash, int var, sc sc_, int flags)
{
  // Add declaration only if not already declared.  Header files must
  // be processed before source files for this to have the right effect.
  // I do not want to handle implicit declarations at the moment.
  member m;
  member found;

  m = found = find_member (current_namespace, name, var, sc_, hash);
  if (m is null)
    m = add_member (current_namespace, name, var, sc_, hash);

  // Definition already seen => probably last declaration implicit.
  // Override.  This means that declarations must always be added to
  // the symbol table before definitions.
  if (!found)
  {
    if (!current_namespace.filename
        || current_namespace.filename != filename)
      m.filename = filename;

    m.regexp = regexp;
    m.pos = pos;
    m.vis = visibility.V_PUBLIC;
    m.flags = flags;

    info_where = P_DECL;
    info_cls = current_namespace;
    info_member = m;
  }
}


// Add a symbol for member NAME to class CLS.
// VAR non-zero means it's a variable.  SC specifies the kind of
// member.  HASH is a hash code for the parameter types of a function.
// Value is a pointer to the member's structure.

static member
add_member (sym cls, string name, int var, sc sc_, uint hash)
{
  member m = new member;
  member[]* list;
  member prev;
  string s;

  m.name = name;
  m.param_hash = hash;

  m.vis = 0;
  m.flags = 0;
  m.regexp = null;
  m.filename = null;
  m.pos = 0;
  m.def_regexp = null;
  m.def_filename = null;
  m.def_pos = 0;

  assert (cls !is null);

  switch (sc_)
  {
    case sc.SC_FRIEND:
      list = &cls.friends;
      break;

    case sc.SC_TYPE:
      list = &cls.types;
      break;

    case sc.SC_STATIC:
      list = var ? &cls.static_vars : &cls.static_fns;
      break;

    default:
      list = var ? &cls.vars : &cls.fns;
      break;
  }


  member_table[name] ~= m;
  m.list = list;

  // Keep the member list sorted.
  auto r = assumeSorted!((a,b) => a.name < b.name)(*list).trisect(m);
  insertInPlace(*list, r[0].length + r[1].length, m);

  return m;
}


// Given the root R of a class tree, step through all subclasses
// recursively, marking functions as virtual that are declared virtual
// in base classes.

static void
mark_virtual (sym r)
{
  foreach (sym_; r.subs)
  {
    foreach (m; r.fns)
      if (has_flag (m.flags, F_VIRTUAL))
      {
        foreach (m2; sym_.fns)
          if (m.param_hash == m2.param_hash && m.name == m2.name)
            set_flag (&m2.flags, F_VIRTUAL);
      }

    mark_virtual (sym_);
  }
}


// For all roots of the class tree, mark functions as virtual that
// are virtual because of a virtual declaration in a base class.

static void
mark_inherited_virtual ()
{
  foreach (class_name, class_list; class_table)
  {
    foreach (r; class_list)
    {
      if (r.supers.empty)
        mark_virtual (r);
    }
  }
}


// Create and return a symbol for a namespace with name NAME.

static sym
make_namespace (string name, sym context)
{
  sym s = new sym;
  s.name = name;
  s.namesp = context;
  all_namespaces ~= s;
  return s;
}


// Find the symbol for namespace NAME.  If not found, return null

static sym
check_namespace (string name, sym context)
{
  foreach (p; all_namespaces)
  {
    if (p.name == name && p.namesp == context)
      return p;
  }

  return null;
}

// Find the symbol for namespace NAME.  If not found, add a new symbol
// for NAME to all_namespaces.

static sym
find_namespace (string name, sym context)
{
  sym p = check_namespace (name, context);

  if (p is null)
    p = make_namespace (name, context);

  return p;
}


// Find namespace alias with name NAME. If not found return null.

static sym[]
check_namespace_alias (string name)
{
  if (name in namespace_alias_table)
  {
    foreach (al; namespace_alias_table[name])
    {
      if (al.namesp == current_namespace)
      {
        return al.aliasee;
      }
    }
  }

  return [];
}

// Register the name NEW_NAME as an alias for namespace list OLD_NAME.

static void
register_namespace_alias (string new_name, sym[] old_name)
{
  if (new_name in namespace_alias_table)
  {
    foreach (al; namespace_alias_table[new_name])
    {
      if (al.namesp == current_namespace)
      {
        return;
      }
    }
  }

  ns_alias al = new ns_alias;
  al.name = new_name;
  al.namesp = current_namespace;
  al.aliasee = old_name;
  namespace_alias_table[new_name] ~= al;
}


// Enter namespace with name NAME.

static void
enter_namespace (string name)
{
  sym p = find_namespace (name, current_namespace);

  namespace_stack ~= current_namespace;
  current_namespace = p;
}


// Leave the current namespace.

static void
leave_namespace ()
{
  assert (!namespace_stack.empty);
  current_namespace = namespace_stack.back;
  namespace_stack.popBack;
}


//**********************************************************************
//				Parser
//**********************************************************************

// Match the current lookahead token and set it to the next token.

void MATCH()
{
  // the end-of-file token sits there so we do not need to test for empty
  // anywhere else
  if (tokens.length > 1)
  {
    tokens = tokens[1 .. $];
  }
}

// Is the current lookahead equal to the token T?

bool LOOKING_AT(TokenType[] tts...)
{
  foreach (tt; tts)
  {
    if (tokens.front.type_ == tt)
    {
      return true;
    }
  }
  return false;
}

// Match token T if current lookahead is T.

void MATCH_IF(TokenType tt)
{
  if (LOOKING_AT(tt))
  {
    MATCH();
  }
}

// Skip to matching token if current token is T.

void SKIP_MATCHING_IF(TokenType tt)
{
  if (LOOKING_AT(tt))
  {
    skip_matching();
  }
}

// Skip forward until a given token TOKEN or YYEOF is seen and return
// the current lookahead token after skipping.

static TokenType
skip_to (TokenType t)
{
  while (!LOOKING_AT (tk!"\0", t))
    MATCH ();
  return tokens.front.type_;
}

// Skip over pairs of tokens (parentheses, square brackets,
// angle brackets, curly brackets) matching the current lookahead.

static void
skip_matching ()
{
  TokenType open, close;

  open = tokens.front.type_;
  switch (open.id)
  {
    case tk!"{".id:
      close = tk!"}";
      break;

    case tk!"(".id:
      close = tk!")";
      break;

    case tk!"<".id:
      close = tk!">";
      break;

    case tk!"[".id:
      close = tk!"]";
      break;

    default:
      abort ();
  }

  for (int n = 0;;)
  {
    if (LOOKING_AT (open))
      ++n;
    else if (LOOKING_AT (close))
      --n;
    else if (LOOKING_AT (tk!"\0"))
      break;

    MATCH ();

    if (n == 0)
      break;
  }
}

static void
skip_initializer ()
{
  for (;;)
  {
    switch (tokens.front.type_.id)
    {
      case tk!";".id:
      case tk!",".id:
      case tk!"\0".id:
        return;

      case tk!"{".id:
      case tk!"[".id:
      case tk!"(".id:
        skip_matching ();
        break;

      default:
        MATCH ();
        break;
    }
  }
}

// Build qualified namespace alias (A::B::c) and return it.

static sym[]
match_qualified_namespace_alias ()
{
  sym[] list;
  sym cur = null;

  for (;;)
  {
    MATCH ();
    switch (tokens.front.type_.id)
    {
      case tk!"identifier".id:
        cur = find_namespace (tokens.front.value, cur);
        list ~= cur;
        break;
      case tk!"::".id:
        // Just skip
        break;
      default:
        return list;
    }
  }
}


// Parse a parameter list, including the const-specifier,
// pure-specifier, and throw-list that may follow a parameter list.
// Return in FLAGS what was seen following the parameter list.
// Returns a hash code for the parameter types.  This value is used to
// distinguish between overloaded functions.

static uint
parm_list (int *flags)
{
  uint hash = 0;
  int type_seen = 0;

  while (!LOOKING_AT (tk!"\0", tk!")"))
  {
    switch (tokens.front.type_.id)
    {
      // Skip over grouping parens or parameter lists in parameter
      // declarations.
      case tk!"(".id:
        skip_matching ();
        break;

        // Next parameter.
      case tk!",".id:
        MATCH ();
        type_seen = 0;
        break;

        // Ignore the scope part of types, if any.  This is because
        // some types need scopes when defined outside of a class body,
        // and don't need them inside the class body.  This means that
        // we have to look for the last IDENT in a sequence of
        // IDENT::IDENT::...
      case tk!"identifier".id:
        if (!type_seen)
        {
          string last_id;
          uint ident_type_hash = 0;

          parse_qualified_param_ident_or_type (last_id);
          if (last_id)
          {
            // LAST_ID null means something like `X::*'.
            foreach (l; last_id)
            {
              ident_type_hash = (ident_type_hash << 1) ^ l;
            }
            hash = (hash << 1) ^ ident_type_hash;
            type_seen = 1;
          }
        }
        else
          MATCH ();
        break;

      case tk!"void".id:
        // This distinction is made to make `func (void)' equivalent
        // to `func ()'.
        type_seen = 1;
        MATCH ();
        if (!LOOKING_AT (tk!")"))
          hash = (hash << 1) ^ tk!"void".id;
        break;

      case tk!"bool".id:      case tk!"char".id:      case tk!"class".id:     case tk!"const".id:
      case tk!"double".id:    case tk!"enum".id:      case tk!"float".id:     case tk!"int".id:
      case tk!"long".id:      case tk!"short".id:     case tk!"signed".id:    case tk!"struct".id:
      case tk!"union".id:     case tk!"unsigned".id:  case tk!"volatile".id:  case tk!"wchar_t".id:
      case tk!"...".id:
        type_seen = 1;
        hash = (hash << 1) ^ tokens.front.type_.id;
        MATCH ();
        break;

      case tk!"*".id:       case tk!"&".id:       case tk!"[".id:       case tk!"]".id:
        hash = (hash << 1) ^ tokens.front.type_.id;
        MATCH ();
        break;

      default:
        MATCH ();
        break;
    }
  }

  if (LOOKING_AT (tk!")"))
  {
    MATCH ();

    if (LOOKING_AT (tk!"const"))
    {
      // We can overload the same function on `const'
      hash = (hash << 1) ^ tk!"const".id;
      set_flag (flags, F_CONST);
      MATCH ();
    }

    if (LOOKING_AT (tk!"throw"))
    {
      MATCH ();
      SKIP_MATCHING_IF (tk!"(");
      set_flag (flags, F_THROW);
    }

    if (LOOKING_AT (tk!"="))
    {
      MATCH ();
      if (LOOKING_AT (tk!"number") && tokens.front.value == "0")
      {
        MATCH ();
        set_flag (flags, F_PURE);
      }
    }
  }

  return hash;
}


// Parse a member declaration within the class body of CLS.  VIS is
// the access specifier for the member (private, protected,
// public).

static void
member_ (sym cls, TokenType vis)
{
  string id;
  sc sc_ = sc.SC_MEMBER;
  string regexp;
  long pos;
  int is_constructor;
  int anonymous = 0;
  int flags = 0;
  TokenType class_tag;
  int type_seen = 0;
  int paren_seen = 0;
  uint hash = 0;
  int tilde = 0;

  while (!LOOKING_AT (tk!";", tk!"{", tk!"}", tk!"\0"))
  {
    switch (tokens.front.type_.id)
    {
      default:
        MATCH ();
        break;

        // A function or class may follow.
      case tk!"template".id:
        MATCH ();
        set_flag (&flags, F_TEMPLATE);
        // Skip over template argument list
        SKIP_MATCHING_IF (tk!"<");
        break;

      case tk!"explicit".id:
        set_flag (&flags, F_EXPLICIT);
        goto typeseen;

      case tk!"mutable".id:
        set_flag (&flags, F_MUTABLE);
        goto typeseen;

      case tk!"inline".id:
        set_flag (&flags, F_INLINE);
        goto typeseen;

      case tk!"virtual".id:
        set_flag (&flags, F_VIRTUAL);
        goto typeseen;

      case tk!"[".id:
        skip_matching ();
        break;

      case tk!"enum".id:
        sc_ = sc.SC_TYPE;
        goto typeseen;

      case tk!"typedef".id:
        sc_ = sc.SC_TYPE;
        goto typeseen;

      case tk!"friend".id:
        sc_ = sc.SC_FRIEND;
        goto typeseen;

      case tk!"static".id:
        sc_ = sc.SC_STATIC;
        goto typeseen;

      case tk!"~".id:
        tilde = 1;
        MATCH ();
        break;

      case tk!"identifier".id:
        // Remember IDENTS seen so far.  Among these will be the member
        // name.
        if (tilde)
        {
          id = "~" ~ tokens.front.value;
        }
        else
          id = tokens.front.value;
        pos = tokens.front.position_;
        MATCH ();
        break;

      case tk!"operator".id:
        {
          string s = operator_name (sc_);
          id = s;
        }
        break;

      case tk!"(".id:
        // Most probably the beginning of a parameter list.
        MATCH ();
        paren_seen = 1;

        if (id && cls)
        {
          is_constructor = id == cls.name;
          if (!is_constructor)
            regexp = matching_regexp ();
        }
        else
          is_constructor = 0;

        pos = tokens.front.position_;
        hash = parm_list (&flags);

        if (is_constructor)
          regexp = matching_regexp ();

        if (id && cls !is null)
          add_member_decl (cls, id, regexp, pos, hash, 0, sc_, vis, flags);

        while (!LOOKING_AT (tk!";", tk!"{", tk!"\0"))
          MATCH ();

        if (LOOKING_AT (tk!"{") && id && cls)
          add_member_defn (cls, id, regexp, pos, hash, 0, sc_, flags);

        id = string.init;
        sc_ = sc.SC_MEMBER;
        break;

      case tk!"struct".id: case tk!"union".id: case tk!"class".id:
        // Nested class
        class_tag = tokens.front.type_;
        type_seen = 1;
        MATCH ();
        anonymous = 1;

        // More than one ident here to allow for MS-DOS specialties
        // like `_export class' etc.  The last IDENT seen counts
        // as the class name.
        while (!LOOKING_AT (tk!"\0", tk!";", tk!":", tk!"{"))
        {
          if (LOOKING_AT (tk!"identifier"))
            anonymous = 0;
          MATCH ();
        }

        if (LOOKING_AT (tk!":", tk!"{"))
          class_definition (anonymous ? null : cls, class_tag, flags, 1);
        else
          skip_to (tk!";");
        break;

      case tk!"int".id:       case tk!"char".id:      case tk!"long".id:      case tk!"unsigned".id:
      case tk!"signed".id:    case tk!"const".id:     case tk!"double".id:    case tk!"void".id:
      case tk!"short".id:     case tk!"volatile".id:  case tk!"bool".id:      case tk!"wchar_t".id:
      case tk!"typename".id:
      typeseen:
          type_seen = 1;
          MATCH ();
          break;
    }
  }

  if (LOOKING_AT (tk!";"))
  {
    // The end of a member variable, a friend declaration or an access
    // declaration.  We don't want to add friend classes as members.
    if (id && sc_ != sc.SC_FRIEND && cls)
    {
      regexp = matching_regexp ();
      pos = tokens.front.position_;

      if (cls !is null)
      {
        if (type_seen || !paren_seen)
          add_member_decl (cls, id, regexp, pos, 0, 1, sc_, vis, 0);
        else
          add_member_decl (cls, id, regexp, pos, hash, 0, sc_, vis, 0);
      }
    }

    MATCH ();
  }
  else if (LOOKING_AT (tk!"{"))
  {
    // A named enum.
    if (sc_ == sc.SC_TYPE && id && cls)
    {
      regexp = matching_regexp ();
      pos = tokens.front.position_;

      if (cls !is null)
      {
        add_member_decl (cls, id, regexp, pos, 0, 1, sc_, vis, 0);
        add_member_defn (cls, id, regexp, pos, 0, 1, sc_, 0);
      }
    }

    skip_matching ();
  }
}


// Parse the body of class CLS.  TAG is the tag of the class (struct,
// union, class).

static void
class_body (sym cls, TokenType tag)
{
  TokenType vis = tag == tk!"class" ? tk!"private" : tk!"public";
  TokenType temp;

  while (!LOOKING_AT (tk!"\0", tk!"}"))
  {
    switch (tokens.front.type_.id)
    {
      case tk!"private".id: case tk!"protected".id: case tk!"public".id:
        temp = tokens.front.type_;
        MATCH ();

        if (LOOKING_AT (tk!":"))
        {
          vis = temp;
          MATCH ();
        }
        else
        {
          // Probably conditional compilation for inheritance list.
          // We don't known whether there comes more of this.
          // This is only a crude fix that works most of the time.
          do
          {
            MATCH ();
          }
          while (LOOKING_AT (tk!"identifier", tk!",")
                 || LOOKING_AT (tk!"public", tk!"protected", tk!"private"));
        }
        break;

      case tk!"typename".id:
      case tk!"using".id:
        skip_to (tk!";");
        break;

        // Try to synchronize
      case tk!"char".id:      case tk!"class".id:     case tk!"const".id:
      case tk!"double".id:    case tk!"enum".id:      case tk!"float".id:     case tk!"int".id:
      case tk!"long".id:      case tk!"short".id:     case tk!"signed".id:    case tk!"struct".id:
      case tk!"union".id:     case tk!"unsigned".id:  case tk!"void".id:      case tk!"volatile".id:
      case tk!"typedef".id:   case tk!"static".id:    case tk!"inline".id:  case tk!"friend".id:
      case tk!"virtual".id:   case tk!"template".id:  case tk!"identifier".id:     case tk!"~".id:
      case tk!"bool".id:      case tk!"wchar_t".id:     case tk!"explicit".id:  case tk!"mutable".id:
        member_ (cls, vis);
        break;

      default:
        MATCH ();
        break;
    }
  }
}


// Parse a qualified identifier.  Current lookahead is IDENT.  A
// qualified ident has the form `X<..>::Y<...>::T<...>.  Returns a
// symbol for that class.

static sym
parse_classname ()
{
  sym last_class = null;

  while (LOOKING_AT (tk!"identifier"))
  {
    last_class = add_sym (tokens.front.value, last_class);
    MATCH ();

    if (LOOKING_AT (tk!"<"))
    {
      skip_matching ();
      set_flag (&last_class.flags, F_TEMPLATE);
    }

    if (!LOOKING_AT (tk!"::"))
      break;

    MATCH ();
  }

  return last_class;
}


// Parse an operator name.  Add the `static' flag to *SC if an
// implicitly static operator has been parsed.  Value is a pointer to
// a static buffer holding the constructed operator name string.

static string
operator_name (ref sc sc_)
{
  string id;
  string s;
  size_t len;

  MATCH ();

  if (LOOKING_AT (tk!"new", tk!"delete"))
  {
    // `new' and `delete' are implicitly static.
    if (sc_ != sc.SC_FRIEND)
      sc_ = sc.SC_STATIC;

    s = tokens.front.value;
    MATCH ();

    id = s;

    // Vector new or delete?
    if (LOOKING_AT (tk!"["))
    {
      id ~= "[";
      MATCH ();

      if (LOOKING_AT (tk!"]"))
      {
        id ~= "]";
        MATCH ();
      }
    }
  }
  else
  {
    size_t tokens_matched = 0;

    id = "operator";

    // Beware access declarations of the form "X::f;" Beware of
    // `operator () ()'.  Yet another difficulty is found in
    // GCC 2.95's STL: `operator == __STL_null_TMPL_ARGS (...'.
    while (!(LOOKING_AT (tk!"(") && tokens_matched)
           && !LOOKING_AT (tk!";", tk!"\0"))
    {
      if (!LOOKING_AT(tk!")") && !LOOKING_AT(tk!"]"))
        id ~= ' ';

      auto tt = tokens.front.type_;
      s = tokens.front.value;
      id ~= s;
      MATCH ();

      // If this is a simple operator like `+', stop now.
      if (!isalpha (s.front) && tt !is tk!"(" && tt !is tk!"[")
        break;

      ++tokens_matched;
    }
  }

  return id;
}


// This one consumes the last IDENT of a qualified member name like
// `X::Y::z'.  This IDENT is returned in LAST_ID.  Value is the
// symbol structure for the ident.

static sym
parse_qualified_ident_or_type (ref string last_id)
{
  sym cls = null;
  string id;
  int enter = 0;

  while (LOOKING_AT (tk!"identifier"))
  {
    id = tokens.front.value;
    last_id = id;
    MATCH ();

    SKIP_MATCHING_IF (tk!"<");

    if (LOOKING_AT (tk!"::"))
    {
      sym pcn = null;
      sym[] pna = check_namespace_alias (id);
      if (pna)
      {
        foreach (n; pna)
        {
          enter_namespace (n.name);
          enter++;
        }
      }
      else
      {
        pcn = check_namespace (id, current_namespace);
        if (pcn)
        {
          enter_namespace (pcn.name);
          enter++;
        }
        else
          cls = add_sym (id, cls);
      }
      last_id = "";
      MATCH ();
    }
    else
      break;
  }

  while (enter--)
    leave_namespace ();

  return cls;
}


// This one consumes the last IDENT of a qualified member name like
// `X::Y::z'.  This IDENT is returned in LAST_ID.  Value is the
// symbol structure for the ident.

static void
parse_qualified_param_ident_or_type (ref string last_id)
{
  sym cls = null;
  string id;

  assert (LOOKING_AT (tk!"identifier"));

  do
  {
    id = tokens.front.value;
    last_id = id;
    MATCH ();

    SKIP_MATCHING_IF (tk!"<");

    if (LOOKING_AT (tk!"::"))
    {
      cls = add_sym (id, cls);
      last_id = "";
      MATCH ();
    }
    else
      break;
  }
  while (LOOKING_AT (tk!"identifier"));
}


// Parse a class definition.

// CONTAINING is the class containing the class being parsed or null.
// This may also be null if NESTED != 0 if the containing class is
// anonymous.  TAG is the tag of the class (struct, union, class).
// NESTED is non-zero if we are parsing a nested class.
//
// Current lookahead is the class name.

static void
class_definition (sym containing, TokenType tag, int flags, int nested)
{
  sym current = null;
  sym base_class = null;

  // Set CURRENT to null if no entry has to be made for the class
  // parsed.  This is the case for certain command line flag
  // settings.
  if ((tag != tk!"class" && !f_structs) || (nested && !f_nested_classes))
    current = null;
  else
  {
    current = add_sym (tokens.front.value, containing);
    current.pos = tokens.front.position_;
    current.regexp = matching_regexp ();
    current.filename = filename;
    current.flags = flags;
  }

  // If at tk!":", base class list follows.
  if (LOOKING_AT (tk!":"))
  {
    int done = 0;
    MATCH ();

    while (!done)
    {
      switch (tokens.front.type_.id)
      {
        case tk!"virtual".id: case tk!"public".id: case tk!"protected".id: case tk!"private".id:
          MATCH ();
          break;

        case tk!"identifier".id:
          base_class = parse_classname ();
          if (base_class && current && base_class != current)
            add_link (base_class, current);
          break;

          // The `,' between base classes or the end of the base
          // class list.  Add the previously found base class.
          // It's done this way to skip over sequences of
          // `A::B::C' until we reach the end.

          // FIXME: it is now possible to handle `class X : public B::X'
          // because we have enough information.
        case tk!",".id:
          MATCH ();
          break;

        default:
          // A syntax error, possibly due to preprocessor constructs
          // like
          //
          // #ifdef SOMETHING
          // class A : public B
          // #else
          // class A : private B.
          //
          // MATCH until we see something like `;' or `{'.
          while (!LOOKING_AT (tk!";", tk!"\0", tk!"{"))
            MATCH ();
          done = 1;
          break;

        case tk!"{".id:
          done = 1;
          break;
      }
    }
  }

  // Parse the class body if there is one.
  if (LOOKING_AT (tk!"{"))
  {
    if (tag != tk!"class" && !f_structs)
      skip_matching ();
    else
    {
      MATCH ();
      class_body (current, tag);

      if (LOOKING_AT (tk!"}"))
      {
        MATCH ();
        if (LOOKING_AT (tk!";") && !nested)
          MATCH ();
      }
    }
  }
}

// Add to class *CLS information for the declaration of variable or
// type *ID.  If *CLS is null, this means a global declaration.  SC is
// the storage class of *ID.  FLAGS is a bit set giving additional
// information about the member (see the F_* defines).

static void
add_declarator (sym *cls, ref string id, int flags, sc sc_)
{
  if (LOOKING_AT (tk!";", tk!","))
  {
    // The end of a member variable or of an access declaration
    // `X::f'.  To distinguish between them we have to know whether
    // type information has been seen.
    if (!id.empty)
    {
      string regexp = matching_regexp ();
      long pos = tokens.front.position_;

      if (*cls)
        add_member_defn (*cls, id, regexp, pos, 0, 1, sc.SC_UNKNOWN, flags);
      else
        add_global_defn (id, regexp, pos, 0, 1, sc_, flags);
    }

    MATCH ();
  }
  else if (LOOKING_AT (tk!"{"))
  {
    if (sc_ == sc.SC_TYPE && id)
    {
      // A named enumeration.
      string regexp = matching_regexp ();
      long pos = tokens.front.position_;
      add_global_defn (id, regexp, pos, 0, 1, sc_, flags);
    }

    skip_matching ();
  }

  *cls = null;
}

// Parse a declaration.

static void
declaration (int flags)
{
  string id;
  sym cls = null;
  string regexp;
  long pos = 0;
  uint hash = 0;
  int is_constructor;
  sc sc_;

  while (!LOOKING_AT (tk!";", tk!"{", tk!"\0"))
  {
    switch (tokens.front.type_.id)
    {
      default:
        MATCH ();
        break;

      case tk!"[".id:
        skip_matching ();
        break;

      case tk!"enum".id:
      case tk!"typedef".id:
        sc_ = sc.SC_TYPE;
        MATCH ();
        break;

      case tk!"static".id:
        sc_ = sc.SC_STATIC;
        MATCH ();
        break;

      case tk!"int".id:       case tk!"char".id:      case tk!"long".id:      case tk!"unsigned".id:
      case tk!"signed".id:    case tk!"const".id:     case tk!"double".id:    case tk!"void".id:
      case tk!"short".id:     case tk!"volatile".id:  case tk!"bool".id:      case tk!"wchar_t".id:
        MATCH ();
        break;

      case tk!"class".id: case tk!"struct".id: case tk!"union".id:
        // This is for the case `STARTWRAP class X : ...' or
        // `declare (X, Y)\n class A : ...'.
        if (id)
        {
          return;
        }
        goto case;

      case tk!"=".id:
        // Assumed to be the start of an initialization in this
        // context.
        skip_initializer ();
        break;

      case tk!",".id:
        add_declarator (&cls, id, flags, sc_);
        break;

      case tk!"operator".id:
        {
          string s = operator_name (sc_);
          id = s;
        }
        break;

      case tk!"inline".id:
        set_flag (&flags, F_INLINE);
        MATCH ();
        break;

      case tk!"~".id:
        MATCH ();
        if (LOOKING_AT (tk!"identifier"))
        {
          id = "~" ~ tokens.front.value;
          MATCH ();
        }
        break;

      case tk!"identifier".id:
        pos = tokens.front.position_;
        cls = parse_qualified_ident_or_type (id);
        break;

      case tk!"(".id:
        // Most probably the beginning of a parameter list.
        if (cls)
        {
          MATCH ();

          if (id && cls)
          {
            is_constructor = id == cls.name;
            if (!is_constructor)
              regexp = matching_regexp ();
          }
          else
            is_constructor = 0;

          pos = tokens.front.position_;
          hash = parm_list (&flags);

          if (is_constructor)
            regexp = matching_regexp ();

          if (id && cls)
            add_member_defn (cls, id, regexp, pos, hash, 0,
                             sc.SC_UNKNOWN, flags);
        }
        else
        {
          // This may be a C functions, but also a macro
          // call of the form `declare (A, B)' --- such macros
          // can be found in some class libraries.
          MATCH ();

          if (id)
          {
            regexp = matching_regexp ();
            pos = tokens.front.position_;
            hash = parm_list (&flags);
            add_global_decl (id, regexp, pos, hash, 0, sc_, flags);
          }

          // This is for the case that the function really is
          // a macro with no `;' following it.  If a CLASS directly
          // follows, we would miss it otherwise.
          if (LOOKING_AT (tk!"class", tk!"struct", tk!"union"))
            return;
        }

        while (!LOOKING_AT (tk!";", tk!"{", tk!"\0"))
          MATCH ();

        if (!cls && id && LOOKING_AT (tk!"{"))
          add_global_defn (id, regexp, pos, hash, 0, sc_, flags);

        break;
    }
  }

  add_declarator (&cls, id, flags, sc_);
}


// Parse a list of top-level declarations/definitions.  START_FLAGS
// says in which context we are parsing.  If it is F_EXTERNC, we are
// parsing in an `extern "C"' block.  Value is 1 if EOF is reached, 0
// otherwise.

static int
globals (int start_flags)
{
  int anonymous;
  TokenType class_tk;
  int flags = start_flags;

  for (;;)
  {
    auto prev_length = tokens.length;

    switch (tokens.front.type_.id)
    {
      case tk!"namespace".id:
        {
          MATCH ();

          if (LOOKING_AT (tk!"identifier"))
          {
            string namespace_name = tokens.front.value;
            MATCH ();

            if (LOOKING_AT (tk!"="))
            {
              sym[] qna = match_qualified_namespace_alias ();
              if (qna)
                register_namespace_alias (namespace_name, qna);

              if (skip_to (tk!";") is tk!";")
                MATCH ();
            }
            else if (LOOKING_AT (tk!"{"))
            {
              MATCH ();
              enter_namespace (namespace_name);
              globals (0);
              leave_namespace ();
              MATCH_IF (tk!"}");
            }
          }
          else if (LOOKING_AT (tk!"{"))
          {
            MATCH ();
            enter_namespace ("<anonymous>");
            globals (0);
            leave_namespace ();
            MATCH_IF (tk!"}");
          }
        }
        break;

      case tk!"extern".id:
        MATCH ();
        if (LOOKING_AT (tk!"string_literal") && tokens.front.value == "\"C\"")
        {
          // This is `extern "C"'.
          MATCH ();

          if (LOOKING_AT (tk!"{"))
          {
            MATCH ();
            globals (F_EXTERNC);
            MATCH_IF (tk!"}");
          }
          else
            set_flag (&flags, F_EXTERNC);
        }
        break;

      case tk!"template".id:
        MATCH ();
        SKIP_MATCHING_IF (tk!"<");
        set_flag (&flags, F_TEMPLATE);
        break;

      case tk!"class".id: case tk!"struct".id: case tk!"union".id:
        class_tk = tokens.front.type_;
        MATCH ();
        anonymous = 1;

        // More than one ident here to allow for MS-DOS and OS/2
        // specialties like `far', `_Export' etc.  Some C++ libs
        // have constructs like `_OS_DLLIMPORT(_OS_CLIENT)' in front
        // of the class name.
        while (!LOOKING_AT (tk!"\0", tk!";", tk!":", tk!"{"))
        {
          if (LOOKING_AT (tk!"identifier"))
            anonymous = 0;
          MATCH ();
        }

        // Don't add anonymous unions.
        if (LOOKING_AT (tk!":", tk!"{") && !anonymous)
          class_definition (null, class_tk, flags, 0);
        else
        {
          if (skip_to (tk!";") == tk!";")
            MATCH ();
        }

        flags = start_flags;
        break;

      case tk!"\0".id:
        return 1;

      case tk!"}".id:
        return 0;

      default:
        declaration (flags);
        flags = start_flags;
        break;
    }

    if (prev_length == tokens.length)
      throw new Exception("parse error");
  }
}


// Parse the current input file.

static void
yyparse ()
{
  while (globals (0) == 0)
    MATCH_IF (tk!"}");
}

void parseFile(string name)
{
  filename = name;
  tokens = tokenize(readText(filename), filename);
  enter_namespace("");
  yyparse();
}

member[] getAllFunctions()
{
  member[] fns;
  foreach (ns; all_namespaces)
  {
    fns ~= ns.static_fns ~ ns.fns;
  }
  return fns;
}

member[] getAllMethods()
{
  member[] fns;
  foreach (k, cls; class_table)
  {
    foreach (c; cls)
    {
      fns ~= c.static_fns ~ c.fns;
    }
  }
  return fns;
}
