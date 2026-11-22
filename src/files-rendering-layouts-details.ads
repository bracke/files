--  The details view's header: its cells, the separators between columns
--  and their grab zones, and the sort each column header asks for. The
--  columns' own geometry (Compute_Detail_Columns) stays with the parent,
--  which places the rows by it.
package Files.Rendering.Layouts.Details is

   --  A details-header cell under a coordinate. Present is False when the
   --  coordinate misses the header band. Column is the column whose cell body
   --  the coordinate falls in, and Command the sort command that a plain click
   --  on it triggers (No_Command for a column that does not sort, e.g. the
   --  permissions column). Callers use Column to begin a reorder drag and
   --  Command to fall back to a sort when the press turns out to be a click.
   type Detail_Header_Cell is record
      Present : Boolean := False;
      Column  : Files.Preference_Types.Detail_Column := Files.Preference_Types.Name_Column;
      Command : Files.Commands.Command_Id := Files.Commands.No_Command;
   end record;

   --  A draggable details-header column separator. Present is False when a
   --  coordinate misses every separator hot zone. Column is the optional column
   --  a drag on this separator resizes (the column whose left edge the separator
   --  is). Origin_X is that left edge in window pixels and Width the column's
   --  current effective width, both captured so a drag can grow or shrink the
   --  column relative to the size it had when the drag began.
   type Detail_Column_Separator is record
      Present  : Boolean := False;
      Column   : Files.Preference_Types.Optional_Detail_Column := Files.Preference_Types.Modified_Column;
      Origin_X : Natural := 0;
      Width    : Natural := 0;
   end record;

   --  Where the divider before a detail column is drawn: this far left of
   --  the column's edge, in the column padding.
   --
   --  @param Column_X Left edge of the column in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return X of the one-pixel divider line.
   function Column_Separator_X (Column_X : Natural; Line_Height : Positive) return Natural
   is (Column_X - Natural'Min (Column_X, Guikit.Layout.Scaled (2, Line_Height)));

   --  Half-width, in reference pixels, of the invisible band around a column
   --  divider where a press begins a column resize: wide enough to grab,
   --  narrow enough that a click well inside a header cell still sorts.
   Column_Separator_Grab_Half_Width : constant := 5;

   --  Whether X is within the resize grab band centred on the divider drawn
   --  before a detail column.
   --
   --  @param Column_X Left edge of the column in pixels.
   --  @param X Pointer X in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return True when a press at X grabs that column's divider.
   function On_Column_Separator (Column_X : Natural; X : Natural; Line_Height : Positive) return Boolean
   is (abs (Integer (X) - Integer (Column_Separator_X (Column_X, Line_Height)))
       <= Guikit.Layout.Scaled (Column_Separator_Grab_Half_Width, Line_Height));

   --  Geometry of the details-view sticky column header: the content rectangle
   --  it spans the top of, its height and inner padding, and the column layout
   --  its cells (and every item row) align to.
   type Details_Header_Layout is record
      Content : Content_Rectangle;
      Height  : Natural := 0;
      Pad     : Natural := 0;
      Columns : Detail_Column_Geometry_Array;
   end record;

   --  The details header geometry for a snapshot and window layout. The header
   --  renderer and the header hit-tests (cell, drop slot, separator) all derive
   --  their rectangles from this one function so they cannot drift apart.
   --
   --  @param Snapshot View snapshot holding the detail-column settings.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return The header's content rectangle, height, padding, and columns.
   function Details_Header_Geometry
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Details_Header_Layout;

   --  Whether a detail column defines a sort and, when it does, the field a
   --  header click on it sorts by.
   type Detail_Column_Sort is record
      Sortable : Boolean := False;
      Field    : Files.Types.Sort_Field := Files.Types.Sort_Name;
   end record;

   --  The one mapping from a detail column to its sort field. The header label
   --  (which column shows the direction indicator) and the header click
   --  hit-test both read it. The permissions column defines no sort.
   Detail_Column_Sorts : constant array (Files.Preference_Types.Detail_Column) of Detail_Column_Sort :=
     [Files.Preference_Types.Name_Column        => (Sortable => True, Field => Files.Types.Sort_Name),
      Files.Preference_Types.Modified_Column    => (Sortable => True, Field => Files.Types.Sort_Changed),
      Files.Preference_Types.Size_Column        => (Sortable => True, Field => Files.Types.Sort_Size),
      Files.Preference_Types.Filetype_Column    => (Sortable => True, Field => Files.Types.Sort_Type),
      Files.Preference_Types.Created_Column     => (Sortable => True, Field => Files.Types.Sort_Created),
      Files.Preference_Types.Permissions_Column => (Sortable => False, Field => Files.Types.Sort_Name)];

end Files.Rendering.Layouts.Details;
