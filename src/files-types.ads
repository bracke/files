with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Files.Gui.Draw;

--  Shared value types used across the files model, commands, and rendering.
package Files.Types is
   subtype UString is Ada.Strings.Unbounded.Unbounded_String;

   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => UString,
      "="          => Ada.Strings.Unbounded."=");

   --  Byte buffer type shared with the renderer-agnostic draw model. Re-exported
   --  from Files.Gui.Draw so the draw model stays domain-free while application
   --  code keeps using Files.Types.Byte_Vectors unchanged.
   package Byte_Vectors renames Files.Gui.Draw.Byte_Vectors;

   type View_Mode is
     (Small_Icons,
      Large_Icons,
      Details);

   --  Selectable detail-view columns. The name column is always shown and
   --  cannot be hidden; the remaining columns are individually toggleable and,
   --  when visible, laid out left to right in this declaration order.
   type Detail_Column is
     (Name_Column,
      Modified_Column,
      Size_Column,
      Filetype_Column,
      Created_Column,
      Permissions_Column);

   --  Toggleable detail columns, i.e. every column except the mandatory name.
   subtype Optional_Detail_Column is
     Detail_Column range Modified_Column .. Permissions_Column;

   --  Per-column visibility flags for the detail view.
   type Detail_Column_Visibility is array (Detail_Column) of Boolean;

   --  Per-column pixel widths for the detail view. A width of zero means the
   --  layout derives a proportional default for that column.
   type Detail_Column_Widths is array (Detail_Column) of Natural;

   --  Default detail-column visibility: name, modified, size, and type are
   --  shown; created and permissions stay hidden until enabled.
   Default_Detail_Column_Visibility : constant Detail_Column_Visibility :=
     [Name_Column        => True,
      Modified_Column    => True,
      Size_Column        => True,
      Filetype_Column    => True,
      Created_Column     => False,
      Permissions_Column => False];

   --  Default per-column widths: zero for every column so the layout derives
   --  proportional defaults until a width is customized.
   Default_Detail_Column_Widths : constant Detail_Column_Widths := [others => 0];

   --  Smallest pixel width a customized detail column may occupy.
   Minimum_Detail_Column_Width : constant := 48;

   --  Number of detail columns; the length of a full column-order permutation.
   Detail_Column_Count : constant := Detail_Column'Pos (Detail_Column'Last) + 1;

   --  One-based slot index into a detail column-order permutation.
   subtype Detail_Column_Index is Positive range 1 .. Detail_Column_Count;

   --  A permutation of every detail column giving their left-to-right order in
   --  the detail view. The mandatory name column always occupies the first
   --  slot; the optional columns are ordered among themselves after it. Hidden
   --  columns still occupy a slot but do not render, so re-showing one restores
   --  it to its ordered position.
   type Detail_Column_Order is array (Detail_Column_Index) of Detail_Column;

   --  Default column order: the declaration (enum) order, name first.
   Default_Detail_Column_Order : constant Detail_Column_Order :=
     [1 => Name_Column,
      2 => Modified_Column,
      3 => Size_Column,
      4 => Filetype_Column,
      5 => Created_Column,
      6 => Permissions_Column];

   --  Return Order with Column moved to occupy slot To_Index (one-based) in the
   --  resulting left-to-right order. The mandatory name column never moves and
   --  always keeps the first slot: a request to move name, or to target the
   --  first slot, is clamped so name stays first. Moving a column to the slot it
   --  already occupies returns Order unchanged. The result is always a
   --  permutation of Order.
   --
   --  @param Order Current column-order permutation.
   --  @param Column Column to move.
   --  @param To_Index Target one-based slot for Column in the result.
   --  @return Updated column-order permutation.
   function Move_Column
     (Order    : Detail_Column_Order;
      Column   : Detail_Column;
      To_Index : Detail_Column_Index)
      return Detail_Column_Order;

   --  A fixed color label (tag) assignable to any item. No_Label means the item
   --  carries no tag; the remaining values name the seven selectable swatch
   --  colors in their canonical display order.
   type Color_Label is
     (No_Label,
      Red,
      Orange,
      Yellow,
      Green,
      Blue,
      Purple,
      Gray);

   --  The seven real (assignable) label colors, excluding the No_Label clear
   --  state. Used to iterate the color swatches and label bands in order.
   subtype Real_Color_Label is Color_Label range Red .. Gray;

   --  Detail-view row grouping mode. When it is not No_Grouping the detail list
   --  gains non-selectable group header rows composed with the active sort.
   type Group_Mode is
     (No_Grouping,
      Group_By_Type,
      Group_By_Modified,
      Group_By_Size,
      Group_By_Label);

   type Item_Kind is
     (Directory_Item,
      Regular_File_Item,
      Symlink_Item,
      Executable_Item,
      Unknown_Item,
      Other_Item);

   type Focus_Target is
     (Focus_None,
      Focus_Path_Input,
      Focus_Filter_Input,
      Focus_Rename_Input,
      Focus_Command_Palette,
      Focus_Settings_Input,
      Focus_Ownership_Input);

   --  Scope the shared filter-bar query applies to. Filter_Here live-filters the
   --  current directory by name (the default), Search_Names replaces the view
   --  with a recursive name search of the subtree, and Search_Contents replaces
   --  it with a recursive content (grep) search. All three reuse one query text.
   type Search_Scope is
     (Filter_Here,
      Search_Names,
      Search_Contents);

   --  Return the search scope reached by cycling one step forward, wrapping from
   --  Search_Contents back to Filter_Here.
   --
   --  @param Scope Current search scope.
   --  @return Next search scope in the cycle.
   function Next_Scope (Scope : Search_Scope) return Search_Scope;

   --  Return Text converted to lower case using simple Ada character folding
   --  plus common UTF-8 Latin-1 uppercase letters.
   --
   --  @param Text Text to normalize.
   --  @return Lower-case version of Text.
   function To_Lower (Text : String) return String;

   --  Return whether Needle occurs in Haystack after case folding.
   --
   --  @param Haystack Text to search.
   --  @param Needle Text to find.
   --  @return True when Needle occurs in Haystack case-insensitively.
   function Contains_Case_Insensitive
     (Haystack : String;
      Needle   : String)
      return Boolean;
end Files.Types;
