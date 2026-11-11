with Ada.Containers.Vectors;

with Files.Types;

--  Pure lazy-loading folder-tree model for the collapsible tree sidebar.
--
--  The tree is a flat list of directory nodes, each remembering its parent, so
--  the structure can be built incrementally and flattened to an ordered list of
--  visible rows without any recursive container types. Nodes are seeded from
--  root locations, then children (subdirectories only) are attached each time
--  a node is expanded, through Replace_Children, which keeps the nodes of
--  children it already holds (matched by path) so a re-read neither grows the
--  tree nor loses an expanded subtree. This package performs no filesystem
--  access: the controller loads a directory, filters it to subdirectories, and
--  hands the children in, keeping the logic here headless and unit-testable.
package Files.Folder_Tree is
   subtype UString is Files.Types.UString;

   type Tree is private;

   --  A node identity supplied when seeding roots or attaching children.
   type Entry_Seed is record
      Path : UString;
      Name : UString;
   end record;

   package Entry_Seed_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Entry_Seed);

   --  One row in the flattened, currently visible projection of the tree.
   type Visible_Row is record
      Node_Index   : Positive := 1;
      Path         : UString;
      Name         : UString;
      Depth        : Natural := 0;
      Expanded     : Boolean := False;
      Loaded       : Boolean := False;
      Has_Children : Boolean := False;
   end record;

   package Visible_Row_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Visible_Row);

   --  Replace all nodes with a fresh set of root nodes at depth zero.
   --
   --  @param T Tree to seed.
   --  @param Roots Root locations shown at the top of the tree.
   procedure Seed
     (T     : out Tree;
      Roots : Entry_Seed_Vectors.Vector);

   --  Return whether the tree has been seeded with root nodes.
   --
   --  @param T Tree to inspect.
   --  @return True once Seed has run at least once.
   function Is_Seeded
     (T : Tree)
      return Boolean;

   --  Return the number of nodes currently held by the tree.
   --
   --  @param T Tree to inspect.
   --  @return Total node count including collapsed descendants.
   function Node_Count
     (T : Tree)
      return Natural;

   --  Return a node's absolute directory path.
   --
   --  @param T Tree to inspect.
   --  @param Index One-based node index.
   --  @return Node path, or an empty string when Index is out of range.
   function Node_Path
     (T     : Tree;
      Index : Positive)
      return String;

   --  Return whether a node is currently expanded.
   --
   --  @param T Tree to inspect.
   --  @param Index One-based node index.
   --  @return True when the node shows its children.
   function Node_Is_Expanded
     (T     : Tree;
      Index : Positive)
      return Boolean;

   --  Attach Children to node Index in place of any it had: a node read
   --  again shows what its folder holds now. A child already attached under
   --  the same path keeps its node, its loaded subtree and its expanded state,
   --  so expanding a folder again does not grow the tree. Children that are
   --  gone are detached, not removed, so every node index stays what it was (a
   --  click keyed on one cannot land on another node).
   --
   --  @param T Tree to update.
   --  @param Index One-based node index.
   --  @param Children Its direct subdirectories now.
   procedure Replace_Children
     (T        : in out Tree;
      Index    : Positive;
      Children : Entry_Seed_Vectors.Vector);

   --  Whether the tree's roots are Roots, in order.
   --
   --  @param T Tree to inspect.
   --  @param Roots Root locations to compare with.
   --  @return True when the tree was seeded with exactly these.
   function Same_Roots
     (T     : Tree;
      Roots : Entry_Seed_Vectors.Vector)
      return Boolean;

   --  Set a node's expanded flag.
   --
   --  @param T Tree to update.
   --  @param Index One-based node index.
   --  @param Expanded New expanded state.
   procedure Set_Expanded
     (T        : in out Tree;
      Index    : Positive;
      Expanded : Boolean);

   --  Flip a node's expanded flag.
   --
   --  @param T Tree to update.
   --  @param Index One-based node index.
   procedure Toggle_Expanded
     (T     : in out Tree;
      Index : Positive);

   --  Flatten the tree into its ordered list of currently visible rows.
   --
   --  Roots are visited in seed order; a node's children are visited, in the
   --  order they were attached, only when the node is expanded, so collapsing a
   --  node hides its whole subtree.
   --
   --  @param T Tree to project.
   --  @return Visible rows in top-to-bottom display order.
   function Visible_Rows
     (T : Tree)
      return Visible_Row_Vectors.Vector;

   --  Count the rows Visible_Rows would return, without building them.
   --
   --  @param T Tree to inspect.
   --  @return Number of currently visible rows.
   function Visible_Row_Count
     (T : Tree)
      return Natural;

private
   type Node is record
      Path         : UString;
      Name         : UString;
      Depth        : Natural := 0;
      Parent       : Natural := 0;
      Expanded     : Boolean := False;
      Loaded       : Boolean := False;
      Has_Children : Boolean := True;
      Rank         : Natural := 0;
      --  Position among its siblings: a child kept across a re-read keeps its
      --  node (and subtree) but takes the place the new listing gives it.
   end record;

   package Node_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Node);

   type Tree is record
      Nodes  : Node_Vectors.Vector;
      Seeded : Boolean := False;
   end record;

end Files.Folder_Tree;
