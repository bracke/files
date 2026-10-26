with Ada.Calendar;
with Ada.Containers.Vectors;

with Files.Breadcrumbs;
with Files.Commands;
with Files.File_System;
with Files.Folder_Tree;
with Files.Shared_Bytes;
with Guikit.Draw;
with Guikit.Item_Grid;
with Guikit.Layout;
with Files.Model;
with Files.Quick_Look;
with Files.Settings;
with Files.Types;
use Guikit.Draw;

--  Immutable render snapshots and layout calculations.
package Files.Rendering is
   subtype UString is Files.Types.UString;

   --  Return the palette color role that renders a color label's swatch/dot.
   --  No_Label resolves to Muted_Text_Color; it is never drawn, so the value
   --  only keeps the mapping total.
   --
   --  @param Label Color label to resolve.
   --  @return The palette role drawn in that label's color.
   function Label_Render_Color
     (Label : Files.Types.Color_Label)
      return Render_Color;

   --  The decoded thumbnail RGBA, wrapped so it takes no part in Item_Snapshot
   --  equality (its "=" is always True). Two snapshots that differ only in
   --  thumbnail pixels compare equal, so the per-frame frame-cache check no
   --  longer walks every pixel of every item. This is safe: a real thumbnail
   --  change also changes the item's Modified_Time or Size (which ARE compared),
   --  and thumbnails only (re)load on a directory re-listing.
   type Thumbnail_Bitmap is record
      Pixels : Files.Shared_Bytes.Bytes;
   end record;
   overriding function "=" (Left, Right : Thumbnail_Bitmap) return Boolean;

   type Item_Snapshot is record
      Name               : UString;
      --  The item's path: what a click on a frame older than the listing is
      --  matched by (a name repeats across folders and in search results).
      Full_Path          : UString;
      Filetype           : UString;
      Filetype_Detail    : UString;
      Icon_Id            : UString;
      Kind               : Files.Types.Item_Kind := Files.Types.Unknown_Item;
      Size_Available     : Boolean := False;
      Size               : Long_Long_Integer := 0;
      Creation_Available : Boolean := False;
      Creation_Time      : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Modified_Available : Boolean := False;
      Modified_Time      : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Permissions        : UString;
      Thumbnail_Available : Boolean := False;
      Thumbnail_Path      : UString;
      Thumbnail_Width     : Natural := 0;
      Thumbnail_Height    : Natural := 0;
      Thumbnail           : Thumbnail_Bitmap;
      Metadata_Error     : Boolean := False;
      Error_Key          : UString;
      Selected           : Boolean := False;
      Visible_Index      : Natural := 0;
      Cut_Pending        : Boolean := False;
      Renaming           : Boolean := False;
      Rename_Value       : UString;
      Rename_Cursor      : Natural := 0;
      --  Non-selectable grouping band header inserted into the detail list when
      --  grouping is active. Group_Label carries the localized band caption and
      --  Visible_Index stays zero so hit-testing never resolves it to an item.
      Is_Group_Header    : Boolean := False;
      Group_Label        : UString;
      --  True when this item's full path is a stored favorite. Drives the
      --  small star indicator drawn over the item's icon in every view mode.
      Is_Favorite        : Boolean := False;
      --  The item's color label (tag). Drives the small colored dot drawn in a
      --  corner of the icon; No_Label draws nothing.
      Label              : Files.Types.Color_Label := Files.Types.No_Label;
   end record;

   package Item_Snapshot_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Item_Snapshot);

   type Info_Snapshot is record
      Name               : UString;
      Filetype           : UString;
      Size_Available     : Boolean := False;
      Size               : Long_Long_Integer := 0;
      Creation_Available : Boolean := False;
      Creation_Time      : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Modified_Available : Boolean := False;
      Modified_Time      : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Permissions        : UString;
      Mode_Available     : Boolean := False;
      Mode_Bits          : Natural := 0;
      Ownership_Available : Boolean := False;
      Owner_Id           : Files.Types.Account_Id := 0;
      Group_Id           : Files.Types.Account_Id := 0;
      Owner_Name         : UString;
      Group_Name         : UString;
      Owner_Editing      : Boolean := False;
      Group_Editing      : Boolean := False;
      Ownership_Buffer   : UString;
      Is_Directory       : Boolean := False;
      Folder_Size_Available : Boolean := False;
      Folder_Size_Bytes     : Long_Long_Integer := 0;
      Folder_File_Count     : Natural := 0;
      Folder_Item_Count     : Natural := 0;
      Folder_Size_Capped    : Boolean := False;
      Metadata_Error     : Boolean := False;
      Error_Key          : UString;
      Filetype_Detail    : UString;
      Filetype_Extra     : UString;
   end record;

   package Info_Snapshot_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Info_Snapshot);

   type Command_Enablement_Array is array (Files.Commands.Registered_Command_Id) of Boolean;

   type View_Snapshot is record
      Current_Path         : UString;
      --  True when Current_Path is a stored favorite. Drives the filled versus
      --  empty star drawn at the left of the path bar.
      Current_Path_Is_Favorite : Boolean := False;
      --  True while the virtual recent-items view is shown, so the empty-state
      --  message reads as an empty recent list rather than an empty directory.
      In_Recent_View       : Boolean := False;
      View_Mode            : Files.Types.View_Mode := Files.Types.Small_Icons;
      Show_Extensions      : Boolean := True;
      Sort_Field           : Files.Types.Sort_Field := Files.Types.Sort_Name;
      Sort_Ascending       : Boolean := True;
      Sort_Menu_Open       : Boolean := False;
      Sort_Menu_Highlight  : Natural := 0;
      Item_Count           : Natural := 0;
      Visible_Count        : Natural := 0;
      Hidden_Count         : Natural := 0;
      Selected_Count        : Natural := 0;
      --  One selected row owns keyboard focus even when selection contains
      --  several rows. This is the one-based visible index, or zero.
      Primary_Selected_Visible_Index : Natural := 0;
      Free_Space_Known      : Boolean := False;
      Free_Space_Bytes      : Long_Long_Integer := 0;
      Total_Space_Bytes     : Long_Long_Integer := 0;
      --  When set, the status bar shows used space (Total - Free) rather than
      --  free space; toggled by clicking the field.
      Show_Used_Space       : Boolean := False;
      --  When set, the free-space field shows a graphical used/free bar instead
      --  of text; takes precedence over Show_Used_Space.
      Show_Space_Bar        : Boolean := False;
      Filter_Text           : UString;
      --  Active filter-bar search scope and whether the current view holds
      --  recursive search results (name or content) rather than a plain
      --  directory listing, so the renderer can draw the scope chip in its
      --  current state and mark the results as a search rather than a directory.
      Search_Scope          : Files.Types.Search_Scope := Files.Types.Filter_Here;
      Search_Results_Active : Boolean := False;
      Last_Error_Key        : UString;
      Focus                 : Files.Types.Focus_Target := Files.Types.Focus_None;
      Text_Cursor_Position  : Natural := 0;
      Path_Input_Text       : UString;
      Path_Input_Valid      : Boolean := True;
      Path_Input_Error_Key  : UString;
      Rename_Active         : Boolean := False;
      Temporary_Item_Active : Boolean := False;
      Temporary_Item_Name   : UString;
      Info_Pane_Open        : Boolean := False;
      --  True when the single selected item's permission bits can be edited in
      --  place through the info-pane rwx grid: exactly one non-trash item is
      --  selected, its mode was read, and the platform supports chmod.
      Permissions_Editable  : Boolean := False;
      --  True when the single selected item's ownership can be edited in the
      --  info pane: exactly one non-trash item is selected, its ownership was
      --  read, and the platform supports chown.
      Ownership_Editable    : Boolean := False;
      Settings_Pane_Open    : Boolean := False;
      Settings_Icon_Theme   : UString;  --  the saved icon theme, for icon rendering
      Theme_Name            : UString;
      Theme_High_Contrast   : Boolean := False;
      Theme_Palette         : Theme_Kind := Theme_Dark;
      Theme_Focus_Ring      : Render_Color := Border_Color;
      Info_Pane_Scroll_Lines : Natural := 0;
      Main_View_Scroll_Lines : Natural := 0;
      Root_Selector_Open    : Boolean := False;
      Root_Selected_Index   : Natural := 0;
      Root_Paths                     : Files.Types.String_Vectors.Vector;
      Root_Labels                    : Files.Types.String_Vectors.Vector;
      Tree_Panel_Open       : Boolean := False;
      Tree_Panel_Scroll_Rows : Natural := 0;
      Tree_Rows             : Files.Folder_Tree.Visible_Row_Vectors.Vector;
      --  Copy to.../Move to... destination picker state driving the tree: when
      --  active the panel shows a Choose/Cancel bar, the title names the copy or
      --  move intent, and the row whose path equals Tree_Pick_Target is marked.
      Tree_Pick_Active      : Boolean := False;
      Tree_Pick_Moving      : Boolean := False;
      Tree_Pick_Target      : UString;
      --  The side panel has the keyboard: the row whose path equals
      --  Tree_Cursor is marked instead of the current folder.
      Tree_Keyboard_Active  : Boolean := False;
      Tree_Cursor           : UString;
      Breadcrumb_Segments   : Files.Breadcrumbs.Segment_Vectors.Vector;
      Command_Palette_Open           : Boolean := False;
      Command_Enabled                : Command_Enablement_Array := [others => False];
      Items                          : Item_Snapshot_Vectors.Vector;
      Selected_Info                  : Info_Snapshot_Vectors.Vector;
      --  Combined size of the whole selection (selected files plus the recursive
      --  size of selected folders). Selection_Total_Pending is True while any
      --  selected folder is still being measured, so the total is not yet final.
      Selection_Total_Bytes          : Long_Long_Integer := 0;
      Selection_Total_Pending        : Boolean := False;
      Context_Menu_Open              : Boolean := False;
      Context_Menu_Highlight         : Natural := 0;
      Context_Menu_X                 : Natural := 0;
      Context_Menu_Y                 : Natural := 0;
      Context_Menu_Target            : Files.Model.Context_Menu_Target :=
        Files.Types.Context_Menu_None;
      Context_Menu_Item_Index        : Natural := 0;
      --  Detail-view column customization mirrored from settings so the pure
      --  layout functions can lay out only the visible columns, honour custom
      --  widths, and insert grouping bands without reaching back into settings.
      Detail_Columns_Visible         : Files.Types.Detail_Column_Visibility :=
        Files.Types.Default_Detail_Column_Visibility;
      Detail_Column_Widths           : Files.Types.Detail_Column_Widths :=
        Files.Types.Default_Detail_Column_Widths;
      Detail_Column_Order            : Files.Types.Detail_Column_Order :=
        Files.Types.Default_Detail_Column_Order;
      Group_By                       : Files.Types.Group_Mode := Files.Types.No_Grouping;
      --  Pending paste-conflict dialog: open when a paste/move is paused waiting
      --  for the user to resolve the colliding destination named Paste_Conflict_Name.
      Paste_Conflict_Open            : Boolean := False;
      Paste_Conflict_Name           : UString;
      Paste_Conflict_Apply_All      : Boolean := False;
      --  Resumable paste progress: open while a long copy/move is in flight,
      --  showing Done/Total, the current item name, and a Cancel button.
      Paste_Progress_Open            : Boolean := False;
      Paste_Progress_Done            : Natural := 0;
      Paste_Progress_Total           : Natural := 0;
      Paste_Progress_Name            : UString;
      Paste_Progress_Moving          : Boolean := False;
      Paste_Progress_Operation_Label : UString;
      --  Quick Look preview overlay: open when previewing a single selected item.
      --  Quick_Look_Kind selects the body (scaled image, capped text lines, or the
      --  metadata info card). Quick_Look_Image_* carry the decoded thumbnail pixels
      --  (reused from the item's thumbnail) the renderer scales to fit; when they
      --  are empty the image body shows a localized empty-preview message.
      Quick_Look_Open                : Boolean := False;
      Quick_Look_Kind                : Files.Quick_Look.Content_Kind :=
        Files.Quick_Look.Info_Content;
      Quick_Look_Name                : UString;
      Quick_Look_Type                : UString;
      Quick_Look_Icon_Id             : UString;
      Quick_Look_Size_Available      : Boolean := False;
      Quick_Look_Size                : Long_Long_Integer := 0;
      Quick_Look_Text_Lines          : Files.Types.String_Vectors.Vector;
      Quick_Look_Text_Truncated      : Boolean := False;
      Quick_Look_Image_Width         : Natural := 0;
      Quick_Look_Image_Height        : Natural := 0;
      Quick_Look_Image_Pixels        : Files.Shared_Bytes.Bytes;
      --  Color-label swatch picker overlay: open when the user is choosing a
      --  label for the current selection.
      Label_Picker_Open              : Boolean := False;
      Label_Picker_Highlight         : Positive := 8;
   end record;

   --  A context-menu row is either a selectable command or a non-selectable
   --  divider that visually groups the commands above and below it.
   type Context_Menu_Row_Kind is (Command_Row, Separator_Row);

   --  Real commands plus the separators that group them. The item menu carries
   --  19 commands split into 6 groups by 5 separators (24 rows); the constant
   --  keeps headroom so the fixed arrays never overflow.
   Max_Context_Menu_Rows : constant := 26;
   type Context_Menu_Command_Array is
     array (1 .. Max_Context_Menu_Rows) of Files.Commands.Command_Id;
   type Context_Menu_Row_Kind_Array is
     array (1 .. Max_Context_Menu_Rows) of Context_Menu_Row_Kind;

   type Context_Menu_Layout is record
      Visible          : Boolean := False;
      X                : Natural := 0;
      Y                : Natural := 0;
      Width            : Natural := 0;
      Height           : Natural := 0;
      Row_Height       : Natural := 0;
      Separator_Height : Natural := 0;
      Padding          : Natural := 0;
      Column_Count     : Positive := 1;
      Column_Width     : Natural := 0;
      Column_Break_Row : Natural := 0;
      Row_Count        : Natural := 0;
      Commands         : Context_Menu_Command_Array :=
        [others => Files.Commands.No_Command];
      Row_Kinds        : Context_Menu_Row_Kind_Array :=
        [others => Command_Row];
   end record;

   --  Calculate the context-menu popup rectangle and per-row geometry.
   --
   --  @param Snapshot Active view snapshot.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Menu layout; Visible is false when no menu should be rendered.
   function Calculate_Context_Menu_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Context_Menu_Layout;

   --  Return the top Y coordinate of a menu row, accounting for the smaller
   --  height of any separator rows above it. Rows have variable heights, so a
   --  simple row * Row_Height offset is not correct; callers (renderer and
   --  hit-tests) use this to place and probe rows consistently.
   --
   --  @param Menu Layout returned by Calculate_Context_Menu_Layout.
   --  @param Row Row index between 1 and Row_Count.
   --  @return Top window Y coordinate of the row.
   function Context_Menu_Row_Top
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural;

   --  Return the left edge of the column containing a menu row.
   --  Compact menus can split at a group boundary into two columns.
   --
   --  @param Menu Layout returned by Calculate_Context_Menu_Layout.
   --  @param Row Row index between 1 and Row_Count.
   --  @return Left window coordinate of the row's column.
   function Context_Menu_Row_Left
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural;

   --  Return the width of the column containing a menu row.
   --
   --  @param Menu Layout returned by Calculate_Context_Menu_Layout.
   --  @param Row Row index between 1 and Row_Count.
   --  @return Width of the row's column.
   function Context_Menu_Row_Width
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural;

   --  Window layout geometry. Re-exported from Guikit.Draw so backends can
   --  consume it without depending on this package; existing
   --  Files.Rendering.Layout_Metrics references keep compiling unchanged.
   subtype Layout_Metrics is Guikit.Draw.Layout_Metrics;

   --  Per-item geometry lives in Guikit.Item_Grid now; these aliases keep the
   --  existing Files.Rendering.Item_Layout / *_Vectors references compiling.
   subtype Item_Layout is Guikit.Item_Grid.Item_Layout;
   package Item_Layout_Vectors renames Guikit.Item_Grid.Item_Layout_Vectors;

   --  Deterministic set of one-based visible item indices. Used to carry the
   --  items a marquee (rubber-band) rectangle touches from the pure hit-test to
   --  the selection reducer.
   package Visible_Index_Vectors renames Guikit.Item_Grid.Visible_Index_Vectors;

   type Main_View_Layout is record
      Columns           : Positive := 1;
      Content_Height    : Natural := 0;
      Scroll_Lines      : Natural := 0;
      Scroll_Pixels     : Natural := 0;
      Scrollbar_Visible : Boolean := False;
      Scrollbar_X       : Natural := 0;
      Scrollbar_Y       : Natural := 0;
      Scrollbar_Thumb_Y : Natural := 0;
      Scrollbar_Width   : Natural := 0;
      Scrollbar_Height  : Natural := 0;
      Scrollbar_Track_Height : Natural := 0;
      --  Row geometry, so callers can tell which rows the viewport shows: an
      --  item at snapshot position P sits on row (P - 1) / Columns, Row_Stride
      --  pixels apart, each Cell_Height tall, in a Viewport_Height window that
      --  scrolls at most Max_Scroll_Pixels.
      Cell_Height       : Natural := 0;
      Row_Stride        : Natural := 0;
      Viewport_Height   : Natural := 0;
      Max_Scroll_Pixels : Natural := 0;
   end record;

   --  Palette overlay geometry lives in Guikit.Layout; kept under the local
   --  name so the renderer and event code read unchanged.
   subtype Command_Palette_Layout is Guikit.Layout.Palette_Layout;

   --  Geometry of the centered Quick Look overlay panel and its inner content
   --  region (inside the padding, below the title band).
   type Quick_Look_Layout is record
      X          : Natural := 0;
      Y          : Natural := 0;
      Width      : Natural := 0;
      Height     : Natural := 0;
      Content_X  : Natural := 0;
      Content_Y  : Natural := 0;
      Content_Width  : Natural := 0;
      Content_Height : Natural := 0;
   end record;

   --  Number of swatches in the color-label picker: the seven assignable colors
   --  plus a trailing "None" swatch that clears the selection's labels.
   Label_Picker_Swatch_Count : constant := 8;

   type Label_Swatch_Bounds is record
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;

   type Label_Swatch_Array is
     array (1 .. Label_Picker_Swatch_Count) of Label_Swatch_Bounds;

   --  Geometry of the centered color-label picker overlay: the outer panel and
   --  its row of clickable swatches. Swatches 1 .. 7 correspond to the colors
   --  Red .. Gray (Files.Types.Real_Color_Label in order); swatch 8 is the
   --  "None" clear swatch.
   type Label_Picker_Layout is record
      X           : Natural := 0;
      Y           : Natural := 0;
      Width       : Natural := 0;
      Height      : Natural := 0;
      Swatch_Size : Natural := 0;
      Swatches    : Label_Swatch_Array;
      Visible     : Boolean := False;
   end record;

   --  Return the color label a picker swatch index selects. Indices 1 .. 7 map
   --  to Red .. Gray; index 8 (and any out-of-range value) maps to No_Label.
   --
   --  @param Index One-based swatch index.
   --  @return The color label the swatch assigns.
   function Label_For_Swatch
     (Index : Positive)
      return Files.Types.Color_Label renames Files.Types.Label_For_Swatch;

   subtype Command_Result_Layout is Guikit.Layout.Palette_Result_Row;

   type Root_Selector_Layout is record
      X          : Natural := 0;
      Y          : Natural := 0;
      Width      : Natural := 0;
      Height     : Natural := 0;
      Row_Height : Natural := 0;
   end record;

   --  Geometry of the centered paste-conflict dialog: the outer panel, its four
   --  action buttons (left to right) and the "apply to all" toggle row.
   type Conflict_Dialog_Layout is record
      X            : Natural := 0;
      Y            : Natural := 0;
      Width        : Natural := 0;
      Height       : Natural := 0;
      Message_X      : Natural := 0;
      Message_Y      : Natural := 0;
      Message_Width  : Natural := 0;
      Message_Height : Natural := 0;
      Apply_X      : Natural := 0;
      Apply_Y      : Natural := 0;
      Apply_Width  : Natural := 0;
      Apply_Height : Natural := 0;
      Button_Y      : Natural := 0;
      Button_Height : Natural := 0;
      Replace_X    : Natural := 0;
      Skip_X       : Natural := 0;
      Rename_X     : Natural := 0;
      Cancel_X     : Natural := 0;
      Button_Width : Natural := 0;
   end record;

   --  Geometry of the centered paste-progress overlay: the outer panel, the
   --  progress-bar track, and the single Cancel button.
   type Paste_Progress_Layout is record
      X             : Natural := 0;
      Y             : Natural := 0;
      Width         : Natural := 0;
      Height        : Natural := 0;
      Message_X      : Natural := 0;
      Message_Y      : Natural := 0;
      Message_Width  : Natural := 0;
      Message_Height : Natural := 0;
      Bar_X         : Natural := 0;
      Bar_Y         : Natural := 0;
      Bar_Width     : Natural := 0;
      Bar_Height    : Natural := 0;
      Cancel_X      : Natural := 0;
      Cancel_Y      : Natural := 0;
      Cancel_Width  : Natural := 0;
      Cancel_Height : Natural := 0;
   end record;

   type Root_Path_Layout is record
      Root_Index : Natural := 0;
      X          : Natural := 0;
      Y          : Natural := 0;
      Width      : Natural := 0;
      Height     : Natural := 0;
      Selected   : Boolean := False;
   end record;

   package Root_Path_Layout_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Root_Path_Layout);

   type Breadcrumb_Segment_Layout is record
      Segment_Index : Natural := 0;
      X             : Natural := 0;
      Y             : Natural := 0;
      Width         : Natural := 0;
      Height        : Natural := 0;
      Clickable     : Boolean := True;
   end record;

   package Breadcrumb_Segment_Layout_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Breadcrumb_Segment_Layout);

   --  Bounding rectangle of the clickable favorite-star toggle drawn at the
   --  left of the path bar, in window pixels. Visible is False when the path
   --  bar is too narrow to reserve room for the star.
   type Path_Favorite_Star_Bounds is record
      X       : Natural := 0;
      Y       : Natural := 0;
      Width   : Natural := 0;
      Height  : Natural := 0;
      Visible : Boolean := False;
   end record;

   type Tree_Panel_Layout is record
      X          : Natural := 0;
      Y          : Natural := 0;
      Width      : Natural := 0;
      Height     : Natural := 0;
      Row_Height : Natural := 0;
      Scrollbar_Visible : Boolean := False;
      Scrollbar_X       : Natural := 0;
      Scrollbar_Y       : Natural := 0;
      Scrollbar_Thumb_Y : Natural := 0;
      Scrollbar_Width   : Natural := 0;
      Scrollbar_Height  : Natural := 0;
      Scrollbar_Track_Height : Natural := 0;
   end record;

   type Tree_Row_Layout is record
      Visible_Row_Index : Natural := 0;
      Node_Index   : Natural := 0;
      X            : Natural := 0;
      Y            : Natural := 0;
      Width        : Natural := 0;
      Height       : Natural := 0;
      Depth        : Natural := 0;
      Expanded     : Boolean := False;
      Has_Children : Boolean := False;
      Selected     : Boolean := False;
      Triangle_X   : Natural := 0;
      Triangle_Y   : Natural := 0;
      Triangle_W   : Natural := 0;
      Triangle_H   : Natural := 0;
   end record;

   package Tree_Row_Layout_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Tree_Row_Layout);

   --  Geometry of the destination picker's Choose (left) and Cancel (right)
   --  button bar drawn along the bottom of the folder-tree panel. Both buttons
   --  share the same Y, Height, and Button_Width.
   type Tree_Pick_Button_Layout is record
      Visible      : Boolean := False;
      Choose_X     : Natural := 0;
      Cancel_X     : Natural := 0;
      Y            : Natural := 0;
      Button_Width : Natural := 0;
      Height       : Natural := 0;
   end record;

   type Info_Pane_Layout is record
      X                 : Natural := 0;
      Y                 : Natural := 0;
      Width             : Natural := 0;
      Height            : Natural := 0;
      Content_Height    : Natural := 0;
      Scroll_Lines      : Natural := 0;
      Scroll_Pixels     : Natural := 0;
      Scrollbar_Visible : Boolean := False;
      Scrollbar_X       : Natural := 0;
      Scrollbar_Y       : Natural := 0;
      Scrollbar_Thumb_Y : Natural := 0;
      Scrollbar_Width   : Natural := 0;
      Scrollbar_Height  : Natural := 0;
      Scrollbar_Track_Height : Natural := 0;
   end record;

   --  Clickable controls of the paste-conflict dialog.
   type Conflict_Hit_Kind is
     (Conflict_Hit_None,
      Conflict_Hit_Replace,
      Conflict_Hit_Skip,
      Conflict_Hit_Rename,
      Conflict_Hit_Cancel,
      Conflict_Hit_Apply_All,
      Conflict_Hit_Progress_Cancel);

   type Conflict_Hit_Region is record
      Kind   : Conflict_Hit_Kind := Conflict_Hit_None;
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;

   package Conflict_Hit_Region_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Conflict_Hit_Region);

   --  A clickable info-pane permission cell. Bit is the 0 .. 8 grid cell index
   --  in row-major order (rows user/group/other, columns read/write/execute),
   --  so the corresponding POSIX mode bit is 2 ** (8 - Bit).
   type Permission_Hit_Region is record
      Present : Boolean := False;
      Bit     : Natural := 0;
      X       : Natural := 0;
      Y       : Natural := 0;
      Width   : Natural := 0;
      Height  : Natural := 0;
   end record;

   package Permission_Hit_Region_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Permission_Hit_Region);

   --  A clickable info-pane ownership value. Is_Group is True for the group
   --  row and False for the owner row; clicking opens the ownership editor.
   type Ownership_Hit_Region is record
      Present  : Boolean := False;
      Is_Group : Boolean := False;
      X        : Natural := 0;
      Y        : Natural := 0;
      Width    : Natural := 0;
      Height   : Natural := 0;
   end record;

   package Ownership_Hit_Region_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Ownership_Hit_Region);

   type Frame_Commands is record
      Layout        : Layout_Metrics;
      Theme_Palette : Theme_Kind := Theme_Dark;
      Rectangles    : Rectangle_Command_Vectors.Vector;
      Triangles     : Triangle_Command_Vectors.Vector;
      Text          : Text_Command_Vectors.Vector;
      Icons         : Icon_Command_Vectors.Vector;
      Overlay_Rectangles : Rectangle_Command_Vectors.Vector;
      Overlay_Text       : Text_Command_Vectors.Vector;
      Tooltips      : Tooltip_Command_Vectors.Vector;
      Accessibility : Accessibility_Node_Vectors.Vector;
      Permission_Hits : Permission_Hit_Region_Vectors.Vector;
      Ownership_Hits : Ownership_Hit_Region_Vectors.Vector;
      Conflict_Hits : Conflict_Hit_Region_Vectors.Vector;
   end record;

   --  Compute the centered paste-conflict dialog geometry for a window.
   --
   --  @param Snapshot View snapshot (used only for consistent sizing).
   --  @param Layout Overall layout metrics for the window.
   --  @param Line_Height Text line height in pixels.
   --  @return Panel, button, and toggle rectangles for the dialog.
   function Calculate_Conflict_Dialog_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Conflict_Dialog_Layout;

   --  Compute the centered paste-progress overlay geometry for a window.
   --
   --  @param Snapshot View snapshot (used only for consistent sizing).
   --  @param Layout Overall layout metrics for the window.
   --  @param Line_Height Text line height in pixels.
   --  @return Panel, progress-bar, and Cancel-button rectangles for the overlay.
   function Calculate_Paste_Progress_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Paste_Progress_Layout;

   type Text_Renderer is private;

   --  Text rasterization outcome and glyph/atlas result. Re-exported from
   --  Guikit.Draw so backends can consume them without depending on this
   --  package; the literal renamings keep qualified Files.Rendering references
   --  (e.g. Files.Rendering.Text_Render_Success) compiling unchanged.
   subtype Text_Render_Status is Guikit.Draw.Text_Render_Status;

   --  Re-export of the successful text-rasterization status literal.
   --  @return The Text_Render_Success value from Guikit.Draw.
   function Text_Render_Success return Text_Render_Status
     renames Guikit.Draw.Text_Render_Success;

   subtype Text_Render_Result is Guikit.Draw.Text_Render_Result;

   --  How many selected items the info pane lists in detail. Past a hundred
   --  the list is unreadable anyway; the selection count shows the extent.
   Max_Info_Items : constant := 100;

   --  Build an immutable snapshot from the mutable model.
   --
   --  @param Model Window model to snapshot.
   --  @return View snapshot for rendering.
   function Build_Snapshot
     (Model : Files.Model.Window_Model)
      return View_Snapshot;

   --  Build an immutable view snapshot with loaded settings summary data.
   --
   --  @param Model Source window model.
   --  @param Settings Loaded settings model.
   --  @return Immutable snapshot safe for rendering.
   function Build_Snapshot
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return View_Snapshot;

   --  The model's visible index of the item drawn at Index in Drawn, a
   --  snapshot that may be older than the model's listing (a watched change,
   --  a key that navigated): the drawn item found again by its path. A name
   --  repeats across folders and in search results, so it is not enough.
   --
   --  @param Drawn The snapshot the frame on screen was built from.
   --  @param Index A visible index in Drawn (0 for none).
   --  @param Model The window's model now.
   --  @return The item's visible index in Model, or 0 when it is gone.
   function Item_Now
     (Drawn : View_Snapshot;
      Index : Natural;
      Model : Files.Model.Window_Model)
      return Natural;

   --  Calculate stable layout metrics for a window.
   --
   --  @param Snapshot View snapshot to lay out.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Layout metrics.
   function Calculate_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Layout_Metrics;

   --  Calculate item rectangles for the active view mode.
   --
   --  @param Snapshot View snapshot to lay out.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @param Whole_Content False for the rectangles on screen, where items
   --    scrolled out of view have no area; True for every item at its place
   --    in the unscrolled content (on-screen Y plus the scroll in pixels), as
   --    a marquee that scrolls the view needs.
   --  @return Item layout rectangles in visible-item order.
   function Calculate_Item_Layout
     (Snapshot      : View_Snapshot;
      Layout        : Layout_Metrics;
      Line_Height   : Positive := 20;
      Whole_Content : Boolean := False)
      return Item_Layout_Vectors.Vector;

   --  Calculate main-view scroll metrics for the current view snapshot.
   --
   --  @param Snapshot Immutable view snapshot.
   --  @param Layout Window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Main-view content and scrollbar layout.
   function Calculate_Main_View_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Main_View_Layout;

   --  The main-view scroll, in lines, that shows the item with Visible_Index
   --  whole: unchanged when it already is, otherwise just far enough that it
   --  becomes the first or the last row in view.
   --
   --  @param Snapshot View snapshot holding the item and the current scroll.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @param Visible_Index Visible index of the item to show.
   --  @return Scroll position in lines.
   function Scroll_Lines_Revealing
     (Snapshot      : View_Snapshot;
      Layout        : Layout_Metrics;
      Line_Height   : Positive;
      Visible_Index : Positive)
      return Natural;

   --  How many whole item rows the main view shows at once (at least one).
   --
   --  @param Snapshot View snapshot to lay out.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Rows in view.
   function Main_View_Page_Rows
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Positive;

   --  The rendered pixel width of Free_Space_Label, or zero when there is no
   --  free field.
   --
   --  @param Snapshot The immutable view snapshot.
   --  @param Line_Height Row height in pixels, sizing the monospace cell.
   --  @return The free-space label width in pixels, or zero.
   function Free_Space_Label_Width
     (Snapshot : View_Snapshot; Line_Height : Positive) return Natural;

   --  Normalize the two corner points of a marquee (rubber-band) drag into an
   --  origin-plus-extent rectangle so a drag in any direction (including up or
   --  left) yields a well-formed rectangle. Start is the press point, Current
   --  the live pointer.
   --
   --  @param Start_X Press-point x coordinate in framebuffer pixels.
   --  @param Start_Y Press-point y coordinate in framebuffer pixels.
   --  @param Current_X Live pointer x coordinate in framebuffer pixels.
   --  @param Current_Y Live pointer y coordinate in framebuffer pixels.
   --  @param X Normalized left edge.
   --  @param Y Normalized top edge.
   --  @param Width Normalized width (Current and Start x distance).
   --  @param Height Normalized height (Current and Start y distance).
   procedure Marquee_Rect
     (Start_X   : Natural;
      Start_Y   : Natural;
      Current_X : Natural;
      Current_Y : Natural;
      X         : out Natural;
      Y         : out Natural;
      Width     : out Natural;
      Height    : out Natural);

   --  How many text lines to auto-scroll the item view during a marquee drag,
   --  given the pointer's y and the scrollable rows region. Negative scrolls up,
   --  positive scrolls down, zero holds. It engages within one Line_Height of the
   --  region's top or bottom edge (so the pointer need not leave the window to
   --  reach beyond the fold), and accelerates with distance past the edge up to
   --  Max_Step lines per call. Lets a rubber-band gesture reach items above or
   --  below the current view.
   --
   --  @param Cursor_Y Pointer y in framebuffer pixels.
   --  @param Region_Top Top of the scrollable rows region in framebuffer pixels.
   --  @param Region_Bottom Bottom of that region in framebuffer pixels.
   --  @param Line_Height Row height in pixels; also the edge-zone thickness.
   --  @param Max_Step Largest step magnitude in lines.
   --  @return Signed line delta (negative up, positive down, zero none).
   function Marquee_Auto_Scroll_Step
     (Cursor_Y      : Integer;
      Region_Top    : Integer;
      Region_Bottom : Integer;
      Line_Height   : Positive;
      Max_Step      : Positive := 4)
      return Integer;

   --  Return the horizontal extent of an item's inline rename field.
   --
   --  Both the renderer and the click hit-test use this so the editable region
   --  they present exactly matches the region a click resolves against.
   --
   --  @param Item Item cell layout.
   --  @param View_Mode Active view mode.
   --  @param Renaming Whether the item is currently being renamed.
   --  @param Field_X Left edge of the rename field.
   --  @param Field_W Width of the rename field.
   procedure Rename_Field_Extent
     (Item      : Item_Layout;
      View_Mode : Files.Types.View_Mode;
      Renaming  : Boolean;
      Field_X   : out Natural;
      Field_W   : out Natural);

   --  A details-header cell under a coordinate. Present is False when the
   --  coordinate misses the header band. Column is the column whose cell body
   --  the coordinate falls in, and Command the sort command that a plain click
   --  on it triggers (No_Command for a column that does not sort, e.g. the
   --  permissions column). Callers use Column to begin a reorder drag and
   --  Command to fall back to a sort when the press turns out to be a click.
   type Detail_Header_Cell is record
      Present : Boolean := False;
      Column  : Files.Types.Detail_Column := Files.Types.Name_Column;
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
      Column   : Files.Types.Optional_Detail_Column := Files.Types.Modified_Column;
      Origin_X : Natural := 0;
      Width    : Natural := 0;
   end record;

   --  Calculate command-palette search and result-section rectangles.
   --
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Command-palette layout rectangles.
   function Calculate_Command_Palette_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Command_Palette_Layout;

   --  Calculate the centered Quick Look overlay panel rectangle and its inner
   --  content region.
   --
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Quick Look panel and content-region geometry.
   function Calculate_Quick_Look_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Quick_Look_Layout;

   --  Calculate the centered color-label picker overlay panel rectangle and its
   --  row of swatch rectangles.
   --
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Label-picker panel and swatch geometry.
   function Calculate_Label_Picker_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Label_Picker_Layout;

   --  Calculate root-selector dropdown rectangle.
   --
   --  @param Snapshot View snapshot containing root selector state.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Root-selector dropdown layout.
   function Calculate_Root_Selector_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Root_Selector_Layout;

   --  Calculate root-selector row rectangles.
   --
   --  @param Snapshot View snapshot containing root paths.
   --  @param Layout Root-selector dropdown layout.
   --  @return Root selector row rectangles in root path order.
   function Calculate_Root_Path_Layout
     (Snapshot : View_Snapshot;
      Layout   : Root_Selector_Layout)
      return Root_Path_Layout_Vectors.Vector;

   --  Calculate clickable breadcrumb segment rectangles inside the path bar.
   --
   --  Returns an empty vector while the path input is focused (edit mode). When
   --  the segments would overflow the path bar the leading segments are elided
   --  through Files.Breadcrumbs so the root and trailing components stay
   --  visible; the elision marker carries Clickable => False.
   --
   --  @param Snapshot View snapshot containing breadcrumb segments and focus.
   --  @param Width Window width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Segment rectangles in left-to-right order.
   function Calculate_Breadcrumb_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Line_Height : Positive := 20)
      return Breadcrumb_Segment_Layout_Vectors.Vector;

   --  Rectangle of the clickable favorite-star toggle at the left of the path
   --  bar. Rendering, the path-bar layout, and click hit-testing all derive the
   --  star's position from this single function so they never drift.
   --
   --  @param Width Window width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Star bounds; Visible is False when the path bar is too narrow.
   function Path_Favorite_Star_Region
     (Width       : Natural;
      Line_Height : Positive := 20)
      return Path_Favorite_Star_Bounds;

   --  Inset of the path and filter input boxes inside their toolbar sections.
   --  Drawing, breadcrumb layout and click-to-caret mapping must all use it,
   --  or a click lands the caret beside the character it was aimed at.
   Toolbar_Field_Margin : constant := 6;

   --  Display columns a focused single-line input scrolls off its left edge so
   --  the caret stays visible: typing at the end of a long path used to happen
   --  behind the field's ellipsis. Stateless, so drawing and click-to-caret
   --  mapping derive the same offset from the same text, cursor and width.
   --
   --  @param Text Field text (UTF-8).
   --  @param Cursor Caret byte offset within Text.
   --  @param Text_Width Pixel width available to the text.
   --  @param Line_Height Text line height in pixels.
   --  @return Columns hidden on the left; zero when the caret already fits.
   function Input_Scroll_Columns
     (Text        : String;
      Cursor      : Natural;
      Text_Width  : Natural;
      Line_Height : Positive)
      return Natural;

   --  Horizontal space reserved at the left of the path bar's interior for the
   --  favorite star, in pixels. Breadcrumbs and the editable path field start
   --  this many pixels further right so they never overlap the star.
   --
   --  @param Width Window width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Reserved width in pixels, or zero when the star is not shown.
   function Path_Bar_Content_Offset
     (Width       : Natural;
      Line_Height : Positive := 20)
      return Natural;

   --  Calculate the folder-tree sidebar panel rectangle.
   --
   --  @param Snapshot View snapshot containing tree state.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Tree sidebar panel layout.
   function Calculate_Tree_Panel_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Tree_Panel_Layout;

   --  Return the number of tree rows that fit below the title and above any
   --  destination-picker button bar.
   --
   --  @param Snapshot View snapshot containing tree-picker state.
   --  @param Layout Tree sidebar panel layout.
   --  @return Number of fully visible rows in the viewport (at least one
   --  when any content height remains).
   function Tree_Row_Capacity
     (Snapshot : View_Snapshot;
      Layout   : Tree_Panel_Layout)
      return Natural;

   --  Largest line offset a scrollable region can take: enough lines to
   --  bring the content's bottom edge into the viewport. Shared by wheel,
   --  track-click, and thumb-drag handling so their limits cannot drift.
   --
   --  @param Content_Height Total content height in pixels.
   --  @param Viewport_Height Visible height in pixels.
   --  @param Line_Height Pixels scrolled per line.
   --  @return Maximum scroll offset in lines; zero when everything fits.
   function Max_Scroll_Lines
     (Content_Height  : Natural;
      Viewport_Height : Natural;
      Line_Height     : Positive)
      return Natural is
     (if Content_Height <= Viewport_Height then 0
      else 1 + (Content_Height - Viewport_Height - 1) / Line_Height);

   --  Calculate folder-tree row rectangles with per-depth indentation.
   --
   --  @param Snapshot View snapshot containing the visible tree rows.
   --  @param Layout Tree sidebar panel layout.
   --  @param Line_Height Text line height in pixels.
   --  @return Tree row rectangles in top-to-bottom order.
   function Calculate_Tree_Row_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Tree_Panel_Layout;
      Line_Height : Positive := 20)
      return Tree_Row_Layout_Vectors.Vector;

   --  Calculate the destination picker's Choose/Cancel button bar geometry from
   --  the folder-tree panel layout. Visible is False when the panel is too small
   --  to host a button row below its title.
   --
   --  @param Panel Folder-tree panel layout.
   --  @param Line_Height Text line height in pixels.
   --  @return Button-bar rectangles; Visible is False when they do not fit.
   function Tree_Pick_Buttons
     (Panel       : Tree_Panel_Layout;
      Line_Height : Positive := 20)
      return Tree_Pick_Button_Layout;

   --  Calculate info-pane content and scrollbar geometry.
   --
   --  @param Snapshot View snapshot containing selected metadata.
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Info-pane layout and scrollbar metrics.
   function Calculate_Info_Pane_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Info_Pane_Layout;

   type Close_Button_Layout is record
      Visible : Boolean := False;
      X       : Natural := 0;
      Y       : Natural := 0;
      Width   : Natural := 0;
      Height  : Natural := 0;
   end record;

   --  Calculate the top-right close (X) button rectangle for an overlay panel.
   --
   --  The button is a single line-height square inset from the panel's
   --  top-right corner, clamped inside the panel bounds. Visible is False when
   --  the panel is too small to host the button. Both the renderer and the
   --  click hit-test derive the button from this one function so they stay in
   --  sync.
   --
   --  @param Panel_X Panel left edge in pixels.
   --  @param Panel_Y Panel top edge in pixels.
   --  @param Panel_Width Panel width in pixels.
   --  @param Panel_Height Panel height in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return Close-button rectangle; Visible is False when it does not fit.
   function Panel_Close_Button
     (Panel_X      : Natural;
      Panel_Y      : Natural;
      Panel_Width  : Natural;
      Panel_Height : Natural;
      Line_Height  : Positive := 20)
      return Close_Button_Layout;

   --  Build a backend-neutral render command list from an immutable snapshot.
   --
   --  The returned commands describe visible filled rectangles and text runs.
   --  Rendering backends consume the commands; this function does not access
   --  the filesystem, mutate model state, or execute commands.
   --
   --  @param Snapshot View snapshot to render.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @param Hover_X Pointer x coordinate in framebuffer pixels.
   --  @param Hover_Y Pointer y coordinate in framebuffer pixels.
   --  @param Has_Hover Whether hover coordinates are currently valid.
   --  @param Pressed_X Pressed pointer x coordinate in framebuffer pixels.
   --  @param Pressed_Y Pressed pointer y coordinate in framebuffer pixels.
   --  @param Has_Press Whether pressed coordinates are currently valid.
   --  @param Drag_Item_Index Visible item index being dragged.
   --  @param Drag_X Drag pointer x coordinate in framebuffer pixels.
   --  @param Drag_Y Drag pointer y coordinate in framebuffer pixels.
   --  @param Has_Drag Whether drag preview coordinates are currently valid.
   --  @param Marquee_Active Whether a rubber-band selection rectangle is active.
   --  @param Marquee_X Marquee left edge in framebuffer pixels.
   --  @param Marquee_Y Marquee top edge in framebuffer pixels.
   --  @param Marquee_W Marquee width in framebuffer pixels.
   --  @param Marquee_H Marquee height in framebuffer pixels.
   --  @return Frame command list for a renderer backend.
   function Build_Frame_Commands
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20;
      Hover_X     : Natural := 0;
      Hover_Y     : Natural := 0;
      Has_Hover   : Boolean := False;
      Pressed_X   : Natural := 0;
      Pressed_Y   : Natural := 0;
      Has_Press   : Boolean := False;
      Drag_Item_Index : Natural := 0;
      Drag_X      : Natural := 0;
      Drag_Y      : Natural := 0;
      Has_Drag    : Boolean := False;
      Marquee_Active : Boolean := False;
      Marquee_X   : Natural := 0;
      Marquee_Y   : Natural := 0;
      Marquee_W   : Natural := 0;
      Marquee_H   : Natural := 0)
      return Frame_Commands;

   --  Return the first known monospace TrueType font available on the system.
   --
   --  @return Font path, or an empty string when no known font is present.
   function Default_Font_Path return String;

   --  Load the text renderer font and initialize the textrender atlas.
   --
   --  @param Renderer Renderer state to initialize.
   --  @param Font_Path TrueType font path.
   --  @param Pixel_Size Glyph rasterization size in pixels.
   --  @param Cell_Width Monospace cell width in pixels.
   --  @param Cell_Height Monospace cell height in pixels.
   --  @param Atlas_Width Glyph atlas width in pixels.
   --  @param Atlas_Height Glyph atlas height in pixels.
   --  @return Text render initialization status.
   function Initialize_Text
     (Renderer     : in out Text_Renderer;
      Font_Path    : String;
      Pixel_Size   : Positive := 16;
      Cell_Width   : Positive := 10;
      Cell_Height  : Positive := 20;
      Atlas_Width  : Positive := 1024;
      Atlas_Height : Positive := 1024)
      return Text_Render_Status;

   --  Whether glyphs built earlier for Renderer still index the atlas its
   --  renderer holds now. Renderers are shared by windows of one size, and
   --  another window's text can grow, empty or reload the atlas: glyphs from
   --  before then point at an atlas that is gone, so they are built again.
   --
   --  @param Renderer The window's text renderer.
   --  @param Glyphs Glyphs Build_Text_Glyphs returned for it.
   --  @return True when Glyphs may be drawn and uploaded as they are.
   function Text_Glyphs_Current (Renderer : Text_Renderer; Glyphs : Text_Render_Result) return Boolean;

   --  Whether Renderer has its fonts: False after an initialization, or a
   --  reload when its pooled renderer went to another size, failed.
   --
   --  @param Renderer The window's text renderer.
   --  @return True when Build_Text_Glyphs can draw with it.
   function Text_Loaded (Renderer : Text_Renderer) return Boolean;

   --  Rasterize frame text commands into glyph draw commands.
   --
   --  This uses textrender glyph metrics and atlas coordinates. Text commands
   --  are decoded from UTF-8 before glyph lookup.
   --
   --  @param Renderer Initialized text renderer.
   --  @param Frame Frame command list containing text commands.
   --  @return Glyph draw commands and atlas state.
   function Build_Text_Glyphs
     (Renderer : in out Text_Renderer;
      Frame    : Frame_Commands)
      return Text_Render_Result;

private
   --  Layout seams shared by the body and the Files.Rendering.Hit child, so
   --  the renderer and the click hit-tests compute the same geometry.

   --  Vertical padding above and below a details-view row (and the header):
   --  the grid's own.
   Details_Row_Padding : constant Natural := Guikit.Item_Grid.Details_Row_Padding;

   --  The main content rectangle: the main-view region inset on all sides by the
   --  content padding, dropping the inset when the region is too small to hold
   --  it. Shared by the item layout, the details header/rows, and their click
   --  hit-tests so they agree on the drawable content area.
   type Content_Rectangle is record
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;

   --  The main content rectangle for a window layout.
   --
   --  @param Layout High-level window layout metrics.
   --  @return The padded main-view content rectangle.
   function Main_Content_Rect (Layout : Layout_Metrics) return Content_Rectangle;

   --  Geometry of one detail-view column: whether it is shown and, when shown,
   --  its left edge and width in window pixels.
   type Detail_Column_Geometry is record
      Visible : Boolean := False;
      X       : Natural := 0;
      Width   : Natural := 0;
   end record;

   type Detail_Column_Geometry_Array is
     array (Files.Types.Detail_Column) of Detail_Column_Geometry;

   --  Lay out the visible detail columns left to right across the row content
   --  area (see the body for the sizing rules). The sticky header, the header
   --  hit-tests, and every item row share it so their columns always align.
   --
   --  @param Visible Per-column visibility flags.
   --  @param Widths Per-column customized widths (zero means default).
   --  @param Order Left-to-right permutation of the columns (name pinned first).
   --  @param Content_X Left edge of the detail content area.
   --  @param Content_W Width of the detail content area.
   --  @param Line_Height Text line height in pixels.
   --  @param Pad Row content padding applied before the icon gutter.
   --  @return Per-column geometry for the visible columns.
   function Compute_Detail_Columns
     (Visible     : Files.Types.Detail_Column_Visibility;
      Widths      : Files.Types.Detail_Column_Widths;
      Order       : Files.Types.Detail_Column_Order;
      Content_X   : Natural;
      Content_W   : Natural;
      Line_Height : Positive;
      Pad         : Natural)
      return Detail_Column_Geometry_Array;

   --  Whether a point lies inside a rectangle; an empty rectangle holds none.
   --
   --  @param X Rectangle left edge.
   --  @param Y Rectangle top edge.
   --  @param Box_W Rectangle width.
   --  @param Box_H Rectangle height.
   --  @param Point_X Point X coordinate.
   --  @param Point_Y Point Y coordinate.
   --  @return True when the point is inside the rectangle.
   function Contains_Rectangle_Point
     (X        : Natural;
      Y        : Natural;
      Box_W    : Natural;
      Box_H    : Natural;
      Point_X  : Natural;
      Point_Y  : Natural)
      return Boolean;

   --  Height of the details-view sticky column header: one text line plus the
   --  row padding above and below, clamped to the content height. The header
   --  drawing, its click hit-tests, and the main-view scroll viewport share it.
   --
   --  @param Content_H Height of the main content rectangle.
   --  @param Line_Height Text line height in pixels.
   --  @return Header height in pixels.
   function Details_Header_Height
     (Content_H   : Natural;
      Line_Height : Positive)
      return Natural;

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
   Detail_Column_Sorts : constant array (Files.Types.Detail_Column) of Detail_Column_Sort :=
     [Files.Types.Name_Column        => (Sortable => True, Field => Files.Types.Sort_Name),
      Files.Types.Modified_Column    => (Sortable => True, Field => Files.Types.Sort_Changed),
      Files.Types.Size_Column        => (Sortable => True, Field => Files.Types.Sort_Size),
      Files.Types.Filetype_Column    => (Sortable => True, Field => Files.Types.Sort_Type),
      Files.Types.Created_Column     => (Sortable => True, Field => Files.Types.Sort_Created),
      Files.Types.Permissions_Column => (Sortable => False, Field => Files.Types.Sort_Name)];

   --  Zero-based index of a left-toolbar button, left to right.
   subtype Toolbar_Button_Index is Natural range 0 .. Guikit.Layout.Toolbar_Button_Count - 1;

   --  The command each left-toolbar button triggers, by button index. The
   --  toolbar renderer and the toolbar click hit-test share this one table.
   Toolbar_Button_Commands : constant array (Toolbar_Button_Index) of Files.Commands.Registered_Command_Id :=
     [Files.Commands.Select_Drive_Command,
      Files.Commands.Navigate_Home_Command,
      Files.Commands.Navigate_Back_Command,
      Files.Commands.Navigate_Forward_Command,
      Files.Commands.Navigate_Parent_Command,
      Files.Commands.Create_File_Command,
      Files.Commands.Delete_Selected_Items_Command];

   --  The first button of the file-action group (create/delete); the buttons
   --  before it form the navigation group. The renderer widens the padding on
   --  both sides of this boundary and draws a divider at its left edge.
   First_File_Action_Button : constant Toolbar_Button_Index := 5;

   type Text_Renderer is record
      Loaded       : Boolean := False;
      --  The pooled renderer it draws with, and the configuration that
      --  renderer must have (another window may have taken the slot since).
      Slot         : Natural := 0;
      Key          : UString;
      Pixel_Size   : Positive := 16;
      Font_Path    : UString;
      Cell_Width   : Positive := 10;
      Cell_Height  : Positive := 20;
      Atlas_Width  : Positive := 1024;
      Atlas_Height : Positive := 1024;
   end record;

end Files.Rendering;
