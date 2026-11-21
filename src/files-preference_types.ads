--  The value types of the view preferences the settings file keeps and the
--  interface shows: the view mode, the detail columns (which are shown, how
--  wide, in what order), the colour labels and the detail grouping. Kept out
--  of Files.Types, which holds the string, path and item values every layer
--  shares, so those stay free of presentation choices.
package Files.Preference_Types is

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

   --  Smallest width a customized detail column may occupy, in reference
   --  units (pixels at the reference line height; scaled with it when drawn).
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

end Files.Preference_Types;
