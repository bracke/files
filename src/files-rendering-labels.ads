with Files.Preference_Types;
with Ada.Calendar;
with Ada.Strings.Unbounded;

with Files.Commands;
with Files.Display_Text;
with Files.Types;
with Guikit.Draw;

--  What the frame shows as text or colour, apart from where: the symbol
--  glyphs, times, sizes and permissions as words, the free-space label, the
--  info pane's fields and their values, the colour a label is drawn in.
--  Files.Rendering.Layouts places them and Files.Rendering.Geometry holds
--  the metrics and wrapping they are measured with. Private to
--  Files.Rendering's own units.
private package Files.Rendering.Labels is

   use Ada.Strings.Unbounded;
   use type Files.Preference_Types.Color_Label;

   --  U+00D7 MULTIPLICATION SIGN, the conventional close-affordance glyph.
   Close_Glyph_Text : constant String :=
     [Character'Val (16#C3#), Character'Val (16#97#)];

   --  Separator drawn between breadcrumb segments; a path-like glyph, not text.
   Breadcrumb_Separator_Text : constant String := ">";

   --  U+2605 BLACK STAR: the filled favorite indicator/toggle glyph, a symbol
   --  rather than translatable text.
   Favorite_Star_Filled_Text : constant String :=
     [Character'Val (16#E2#), Character'Val (16#98#), Character'Val (16#85#)];

   --  The same star as drawn over a favorite's icon, converted once rather
   --  than once a row a frame.
   Favorite_Star_Glyph : constant UString := To_Unbounded_String (Favorite_Star_Filled_Text);

   --  Folder-tree expander glyphs: a plus/minus affordance, not translatable text.
   Tree_Expander_Collapsed_Text : constant String := "+";
   Tree_Expander_Expanded_Text  : constant String := "-";

   --  @param Value A time.
   --  @return Its clock time in the locale's hour cycle.
   function Clock_Time_Text (Value : Ada.Calendar.Time) return String renames Files.Display_Text.Clock_Time_Text;

   --  @param Value A time.
   --  @return Its full date and clock time.
   function Full_Time_Text (Value : Ada.Calendar.Time) return String renames Files.Display_Text.Full_Time_Text;

   --  @param Value A time.
   --  @return The localization key of its weekday's name.
   function Weekday_Key (Value : Ada.Calendar.Time) return String renames Files.Display_Text.Weekday_Key;

   --  @param Value The time to show.
   --  @param Now The time it is shown at (the snapshot's).
   --  @return Value as a listing shows it, relative to Now.
   function Humanized_Time_Text
     (Value : Ada.Calendar.Time;
      Now   : Ada.Calendar.Time)
      return String renames Files.Display_Text.Humanized_Time_Text;

   --  @param Value A number.
   --  @return It with the locale's digit grouping.
   function Grouped_Integer_Text (Value : Long_Long_Integer) return String
     renames Files.Display_Text.Grouped_Integer_Text;

   --  @param Value A measure, such as an image's width.
   --  @return It in the locale's digits, ungrouped.
   function Digits_Text (Value : Natural) return String
     renames Files.Display_Text.Digits_Text;

   --  @param Value A byte count.
   --  @return It as a size ("1.2 MB").
   function Size_Text (Value : Long_Long_Integer) return String renames Files.Display_Text.Size_Text;

   --  @param Id A command.
   --  @return Its localized name.
   function Command_Label (Id : Files.Commands.Command_Id) return UString;

   --  The bottom bar's name for a command: the short form where the bar has
   --  one (view modes, info toggle, sort), else its name.
   --
   --  @param Id A command.
   --  @return The label.
   function Bottom_Command_Label (Id : Files.Commands.Command_Id) return UString;

   --  @param Field A sort field.
   --  @return Its localized name.
   function Sort_Field_Label (Field : Files.Types.Sort_Field) return String;

   --  @param Ascending The sort direction.
   --  @return Its localized arrow or word.
   function Direction_Text (Ascending : Boolean) return String;

   --  @param Field The sort field.
   --  @param Ascending The sort direction.
   --  @return The sort button's label: the field and the direction.
   function Sort_Button_Label (Field : Files.Types.Sort_Field; Ascending : Boolean) return UString;

   --  @param Snapshot The view snapshot.
   --  @return The three counts alone, "hidden/visible/selected", for a bar
   --    too narrow for Count_Status_Text.
   function Compact_Count_Status_Text (Snapshot : View_Snapshot) return String;

   --  @return The legend of the compact counts, " (hidden / visible /
   --    selected)" in the status labels, for the counts' tooltip.
   function Count_Legend_Text return String;

   --  @param Snapshot The view snapshot.
   --  @return The bottom bar's info line: the error line when there is one,
   --    else Count_Status_Text.
   function Bottom_Info_Text (Snapshot : View_Snapshot) return UString;

   --  @param Snapshot The view snapshot.
   --  @return The main view's accessibility description: its view mode and
   --    the counts.
   function Main_View_Accessible_Description (Snapshot : View_Snapshot) return UString;

   --  @param Snapshot The view snapshot.
   --  @return The localization key of what the empty main view says (an
   --    empty recent list, folder or filter result), or "" when it has items.
   function Empty_State_Key (Snapshot : View_Snapshot) return String;

   --  @param Label_Key Localization key of the label.
   --  @param Available The time is known.
   --  @param Value The time.
   --  @param Now The time it is shown at (the snapshot's).
   --  @return "Label: <time>" relative to Now, or that it is unknown.
   function Labelled_Time_Text
     (Label_Key : String;
      Available : Boolean;
      Value     : Ada.Calendar.Time;
      Now       : Ada.Calendar.Time)
      return UString;

   --  @param Item A row.
   --  @return The details view's size cell: the size, or "" when unknown.
   function Detail_Size_Text (Item : Item_Snapshot) return UString is
     (if Item.Size_Available then To_Unbounded_String (Size_Text (Item.Size)) else Null_Unbounded_String);

   --  The localized details column names, looked up once a frame, not once
   --  a row.
   --
   --  @return Each column's name.
   function Detail_Names return Detail_Column_Texts;

   --  @param Names The details column names (Detail_Names).
   --  @param Cells The row's cells as drawn; only the visible columns' are read.
   --  @param Order The details columns' left-to-right order.
   --  @param Visible Which details columns are shown.
   --  @param Item The row.
   --  @param Details The view is the details view.
   --  @return What a screen reader says of the row beyond its name: in the
   --    details view each shown column after the name with a value, named,
   --    in the order they are drawn; in an icon view its type.
   function Item_Accessible_Description
     (Names   : Detail_Column_Texts;
      Cells   : Detail_Column_Texts;
      Order   : Files.Preference_Types.Detail_Column_Order;
      Visible : Files.Preference_Types.Detail_Column_Visibility;
      Item    : Item_Snapshot;
      Details : Boolean)
      return UString;

   --  Whether the free-space field should render the graphical used/free bar
   --  (bar mode selected and the capacity totals are usable). When False the
   --  field falls back to the free/used text label.
   --
   --  @param Snapshot The immutable view snapshot.
   --  @return True when the field should draw the used/free bar.
   function Free_Space_Bar_Active (Snapshot : View_Snapshot) return Boolean is
     (Snapshot.Show_Space_Bar
      and then Snapshot.Free_Space_Known
      and then Length (Snapshot.Last_Error_Key) = 0
      and then Snapshot.Free_Space_Bytes >= 0
      and then Snapshot.Total_Space_Bytes > 0
      and then Snapshot.Total_Space_Bytes >= Snapshot.Free_Space_Bytes);

   --  The bottom-bar free-space field's text, e.g. "12 GB free", or the empty
   --  string when free space is unknown or an error line is showing. Shared by
   --  the renderer (to draw) and the hit-test (to locate the field), so both
   --  agree on where the free-space field begins.
   --
   --  @param Snapshot The immutable view snapshot.
   --  @return The free-space label text, or "" when there is no free field.
   function Free_Space_Label (Snapshot : View_Snapshot) return String;

   --  @param Permissions "rwx"-style text for one class.
   --  @param Inline True to join the parts on one line.
   --  @return The readable, writable and executable words, or "none".
   function Permission_Text (Permissions : String; Inline : Boolean := False) return String
     renames Files.Display_Text.Permission_Text;

   --  Build the ordered coalesced sections for the current multi-item selection.
   --  Each section carries one value per selected item so the layout and the
   --  renderer stay in lock-step. Intended for Selected_Info.Length >= 2.
   --
   --  @param Snapshot View snapshot holding the selected-item info blocks.
   --  @return The ordered sections, each with one display value per selected item.
   function Build_Coalesced_Info_Sections
     (Snapshot : View_Snapshot)
      return Coalesced_Section_Vectors.Vector;

   --  The sections Build_Snapshot_Into formatted, or formatted now for a
   --  snapshot assembled another way.
   --
   --  @param Snapshot The view snapshot.
   --  @return The ordered coalesced sections.
   function Coalesced_Info_Sections
     (Snapshot : View_Snapshot)
      return Coalesced_Section_Vectors.Vector is
     (if Snapshot.Info_Sections_Built then Snapshot.Info_Sections else Build_Coalesced_Info_Sections (Snapshot));

   --  A details-view time cell, or that the time is unknown: as the info
   --  pane shows a time.
   --
   --  @param Available The time is known.
   --  @param Value The time.
   --  @param Now The time it is shown at (the snapshot's).
   --  @return The text.
   function Detail_Time_Text
     (Available : Boolean;
      Value     : Ada.Calendar.Time;
      Now       : Ada.Calendar.Time)
      return UString;

   --  The fields of an item's info block. Name is the pane's heading; the
   --  remaining fields are the single-item pane's labelled sections, and their
   --  declaration order is the order those sections are drawn top to bottom.
   --  The renderer and the row count (Info_Section_Row_Count) both walk
   --  Info_Section_Field in this order, so the drawn rows and the scroll extent
   --  cannot drift apart.
   type Info_Field is
     (Info_Name,
      Info_Filetype,
      Info_Size,
      Info_Folder_Size,
      Info_Created,
      Info_Modified,
      Info_Permissions,
      Info_Owner,
      Info_Group,
      Info_Metadata_Error,
      Info_Extra);

   --  The labelled sections of the single-item info pane, in drawing order.
   subtype Info_Section_Field is Info_Field range Info_Filetype .. Info_Extra;

   --  The localization key of an info section's label.
   --
   --  @param Field Info section.
   --  @return The section label's localization key.
   function Info_Field_Label_Key (Field : Info_Section_Field) return String is
     (case Field is
         when Info_Filetype       => "info.filetype",
         when Info_Size           => "info.size",
         when Info_Folder_Size    => "info.folder_size",
         when Info_Created        => "info.created",
         when Info_Modified       => "info.modified",
         when Info_Permissions    => "info.permissions",
         when Info_Owner          => "info.owner",
         when Info_Group          => "info.group",
         when Info_Metadata_Error => "info.metadata_error",
         when Info_Extra          => "info.extra");

   --  Whether the single-item info pane shows a section for an item. Filesize
   --  is file-only (a folder shows Contents instead, once its size is known);
   --  permissions need the item's mode, owner/group its ownership, and the
   --  metadata-error row appears only when metadata actually failed.
   --
   --  @param Info The selected-item info block.
   --  @param Field Info section.
   --  @return True when the section is drawn for this item.
   function Info_Field_Shown
     (Info  : Info_Snapshot;
      Field : Info_Section_Field)
      return Boolean is
     (case Field is
         when Info_Size           => not Info.Is_Directory,
         when Info_Folder_Size    => Info.Is_Directory and then Info.Folder_Size_Available,
         when Info_Permissions    => Info.Mode_Available,
         when Info_Owner
            | Info_Group          => Info.Ownership_Available,
         when Info_Metadata_Error => Info.Metadata_Error,
         when Info_Filetype
            | Info_Created
            | Info_Modified
            | Info_Extra          => True);

   --  An info field's value as the pane shows it.
   --
   --  @param Info The item's info block.
   --  @param Field The field.
   --  @param Now The time relative times are shown at (the snapshot's).
   --  @return The value.
   function Info_Field_Value
     (Info  : Info_Snapshot;
      Field : Info_Field;
      Now   : Ada.Calendar.Time)
      return UString;

   --  Info_Field_Value with the extra-info sentences each on a line.
   --
   --  @param Info The item's info block.
   --  @param Field The field.
   --  @param Now The time relative times are shown at (the snapshot's).
   --  @return The value as drawn.
   function Info_Field_Display_Value
     (Info  : Info_Snapshot;
      Field : Info_Field;
      Now   : Ada.Calendar.Time)
      return UString;

   --  Placeholder shown for an item a section does not apply to. ASCII so it is
   --  always covered by the glyph atlas (the live-smoke asserts no missing glyphs).
   Coalesced_Placeholder : constant String := "-";

   --  Return the palette color role that renders a color label's swatch/dot.
   --  No_Label resolves to Muted_Text_Color; it is never drawn, so the value
   --  only keeps the mapping total.
   --
   --  @param Label Color label to resolve.
   --  @return The palette role drawn in that label's color.
   function Label_Render_Color
     (Label : Files.Preference_Types.Color_Label)
      return Guikit.Draw.Render_Color;

private

   --  @param Value A count.
   --  @return It with the locale's digit grouping (12.345, not 12345), as
   --    sizes and paste-progress counts are shown.
   function Grouped_Natural_Text (Value : Natural) return String is
     (Grouped_Integer_Text (Long_Long_Integer (Value)));

   --  @param Mode A view mode.
   --  @return Its localized name.
   function View_Mode_Label (Mode : Files.Preference_Types.View_Mode) return String;

   --  @param Snapshot The view snapshot.
   --  @return The labelled hidden, visible and selected counts ("3 hidden
   --    12 visible  1 selected (4 KB)"); a selection's total size carries
   --    " ..." while a folder in it is still measured.
   function Count_Status_Text (Snapshot : View_Snapshot) return UString;

   --  @param Label_Key Localization key of the label.
   --  @param Value The value.
   --  @return "Label: Value".
   function Info_Value (Label_Key : String; Value : String) return UString;

   --  What a folder's info pane says it holds: its size and item count once
   --  measured, or that it is being measured.
   --
   --  @param Info The folder's info block.
   --  @return The text.
   function Folder_Contents_Text (Info : Info_Snapshot) return UString;

   --  A time the info pane shows, or that it is unknown.
   --
   --  @param Available The time is known.
   --  @param Value The time.
   --  @param Now The time it is shown at (the snapshot's).
   --  @return The text.
   function Info_Metadata_Text
     (Available : Boolean;
      Value     : Ada.Calendar.Time;
      Now       : Ada.Calendar.Time)
      return UString;

   --  The " (<name>)" suffix appended to coalesced multi-selection values so a
   --  row shows which item it describes. A single-item pane renders the name
   --  once as its heading instead of repeating it after every value.
   --
   --  @param Info The selected-item info block.
   --  @return The parenthesised item-name suffix.
   function Info_Postfix (Info : Info_Snapshot) return String;

end Files.Rendering.Labels;
