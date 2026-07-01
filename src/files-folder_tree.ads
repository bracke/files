with Ada.Containers.Vectors;

with Files.Types;

--  Pure lazy-loading folder-tree model for the collapsible tree sidebar.
--
--  The tree is a flat list of directory nodes, each remembering its parent, so
--  the structure can be built incrementally and flattened to an ordered list of
--  visible rows without any recursive container types. Nodes are seeded from
--  root locations, then children (subdirectories only) are attached lazily the
--  first time a node is expanded. This package performs no filesystem access:
--  the controller loads a directory, filters it to subdirectories, and hands
--  the children in through Set_Children, keeping the logic here headless and
--  unit-testable.
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

   --  Return whether a node's children have been loaded.
   --
   --  @param T Tree to inspect.
   --  @param Index One-based node index.
   --  @return True when Set_Children has run for the node.
   function Node_Is_Loaded
     (T     : Tree;
      Index : Positive)
      return Boolean;

   --  Return whether a node is currently expanded.
   --
   --  @param T Tree to inspect.
   --  @param Index One-based node index.
   --  @return True when the node shows its children.
   function Node_Is_Expanded
     (T     : Tree;
      Index : Positive)
      return Boolean;

   --  Return the first node index whose path matches Path, or zero when none.
   --
   --  @param T Tree to inspect.
   --  @param Path Absolute directory path to find.
   --  @return One-based node index, or zero when no node matches.
   function Index_For_Path
     (T    : Tree;
      Path : String)
      return Natural;

   --  Attach a node's child subdirectories and mark it loaded.
   --
   --  Children are appended once; the node's expandability is derived from the
   --  number of children so a node with no subdirectories loses its expander.
   --  Re-attaching children to an already loaded node is ignored.
   --
   --  @param T Tree to update.
   --  @param Index One-based parent node index.
   --  @param Children Child subdirectories in display order.
   procedure Set_Children
     (T        : in out Tree;
      Index    : Positive;
      Children : Entry_Seed_Vectors.Vector);

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

private
   type Node is record
      Path         : UString;
      Name         : UString;
      Depth        : Natural := 0;
      Parent       : Natural := 0;
      Expanded     : Boolean := False;
      Loaded       : Boolean := False;
      Has_Children : Boolean := True;
   end record;

   package Node_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Node);

   type Tree is record
      Nodes  : Node_Vectors.Vector;
      Seeded : Boolean := False;
   end record;

end Files.Folder_Tree;
