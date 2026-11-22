with Files.Preference_Types;
with Ada.Calendar;
with Ada.Containers;
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Vectors;

with Files.Breadcrumbs;
with Files.Commands;
with Files.File_Types;
with Files.Folder_Tree;
with Files.Icon_Themes;
with Guikit.Shared_Bytes;
with Guikit.Draw;
with Guikit.Item_Grid;
with Guikit.Layout;
with Files.Model;
with Files.Quick_Look;
with Files.Settings;
with Files.Types;
with Files.UI_Types;

--  Immutable render snapshots and the frame commands built from them. Where
--  things lie is worked out in Files.Rendering.Layouts, hit-tested in
--  Files.Rendering.Hit, and text is rasterized by Files.Rendering.Text.
package Files.Rendering is
   subtype UString is Files.Types.UString;

   --  The decoded thumbnail RGBA, wrapped so it takes no part in Item_Snapshot
   --  equality (its "=" is always True). Two snapshots that differ only in
   --  thumbnail pixels compare equal, so the per-frame frame-cache check no
   --  longer walks every pixel of every item. This is safe: a real thumbnail
   --  change also changes the item's Modified_Time or Size (which ARE compared),
   --  and thumbnails only (re)load on a directory re-listing.
   type Thumbnail_Bitmap is record
      Pixels : Guikit.Shared_Bytes.Bytes;
   end record;
   overriding function "=" (Left, Right : Thumbnail_Bitmap) return Boolean;

   type Item_Snapshot is record
      Name               : UString;
      --  The item's path: what a click on a frame older than the listing is
      --  matched by (a name repeats across folders and in search results).
      Full_Path          : UString;
      Filetype           : UString;
      Filetype_Detail    : UString;
      --  The icon, resolved once when the snapshot is built; drawing does not
      --  decide it again.
      Icon               : Files.File_Types.Icon_Kind := Files.File_Types.Unknown_Icon;
      Kind               : Files.Types.Item_Kind := Files.Types.Unknown_Item;
      Size_Available     : Boolean := False;
      Size               : Long_Long_Integer := 0;
      Creation_Available : Boolean := False;
      Creation_Time      : Ada.Calendar.Time := Files.Types.Unknown_Time;
      Modified_Available : Boolean := False;
      Modified_Time      : Ada.Calendar.Time := Files.Types.Unknown_Time;
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
      Label              : Files.Preference_Types.Color_Label := Files.Preference_Types.No_Label;
   end record;

   package Item_Snapshot_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Item_Snapshot);

   package Row_Index_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Positive);

   type Info_Snapshot is record
      Name               : UString;
      Filetype           : UString;
      Size_Available     : Boolean := False;
      Size               : Long_Long_Integer := 0;
      Creation_Available : Boolean := False;
      Creation_Time      : Ada.Calendar.Time := Files.Types.Unknown_Time;
      Modified_Available : Boolean := False;
      Modified_Time      : Ada.Calendar.Time := Files.Types.Unknown_Time;
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

   --  One coalesced info-pane section for a multi-item selection: a single field
   --  label plus the per-item display values (one entry per selected item, in
   --  order, with placeholders already filled for items the field omits).
   package Info_Value_Vectors renames Files.Types.String_Vectors;

   type Coalesced_Section is record
      Key    : UString;
      Values : Info_Value_Vectors.Vector;
   end record;

   package Coalesced_Section_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Coalesced_Section);

   type Command_Enablement_Array is array (Files.Commands.Registered_Command_Id) of Boolean;

   --  One volume root the root selector lists: its full path and the label
   --  the selector shows for it.
   type Root_Row is record
      Path  : UString;
      Label : UString;
   end record;

   package Root_Row_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Root_Row);

   --  Resumable paste progress: open while a long copy/move is in flight,
   --  showing Done/Total, the current item name, and a Cancel button. A
   --  background operation names itself with Operation_Label instead of the
   --  copy or move verb. Every default is the closed state.
   type Paste_Progress_Snapshot is record
      Open            : Boolean := False;
      Done            : Natural := 0;
      Total           : Natural := 0;
      Name            : UString;
      Moving          : Boolean := False;
      Operation_Label : UString;
   end record;

   --  Quick Look preview overlay: open when previewing a single selected item.
   --  Kind selects the body (scaled image, capped text lines, or the metadata
   --  info card). Image_* carry the decoded preview pixels (or the item's
   --  thumbnail) the renderer scales to fit; when they are empty the image
   --  body shows a localized empty-preview message. Every default is the
   --  closed state.
   type Quick_Look_Snapshot is record
      Open           : Boolean := False;
      Kind           : Files.Quick_Look.Content_Kind := Files.Quick_Look.Info_Content;
      Name           : UString;
      Filetype       : UString;
      Icon           : Files.File_Types.Icon_Kind := Files.File_Types.Unknown_Icon;
      Size_Available : Boolean := False;
      Size           : Long_Long_Integer := 0;
      Text_Lines     : Files.Types.String_Vectors.Vector;
      Text_Truncated : Boolean := False;
      Image_Width    : Natural := 0;
      Image_Height   : Natural := 0;
      Image_Pixels   : Guikit.Shared_Bytes.Bytes;
   end record;

   type View_Snapshot is record
      --  The start of the wall-clock minute the snapshot shows the folder
      --  at: the "now" every relative time in it is drawn against, so a
      --  frame is a function of its snapshot and two snapshots built within
      --  a minute agree (Files.Application.Snapshot_Slots rebuilds when it moves on).
      Now                  : Ada.Calendar.Time := Files.Types.Unknown_Time;
      Current_Path         : UString;
      --  True when Current_Path is a stored favorite. Drives the filled versus
      --  empty star drawn at the left of the path bar.
      Current_Path_Is_Favorite : Boolean := False;
      --  True while the virtual recent-items view is shown, so the empty-state
      --  message reads as an empty recent list rather than an empty directory.
      In_Recent_View       : Boolean := False;
      View_Mode            : Files.Preference_Types.View_Mode := Files.Preference_Types.Small_Icons;
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
      Search_Scope          : Files.UI_Types.Search_Scope := Files.UI_Types.Filter_Here;
      Search_Results_Active : Boolean := False;
      Last_Error_Key        : UString;
      --  The last error's message, in the user's language, with the path
      --  it names (error.rename.stranded) filled in.
      Last_Error_Text       : UString;
      Focus                 : Files.UI_Types.Focus_Target := Files.UI_Types.Focus_None;
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
      Icon_Theme            : Files.Icon_Themes.Icon_Theme := Files.Icon_Themes.Basic;
      Theme_Palette         : Guikit.Draw.Theme_Kind := Guikit.Draw.Theme_Dark;
      Theme_Focus_Ring      : Guikit.Draw.Render_Color := Guikit.Draw.Border_Color;
      Info_Pane_Scroll_Lines : Natural := 0;
      Main_View_Scroll_Lines : Natural := 0;
      Root_Selector_Open    : Boolean := False;
      Root_Selected_Index   : Natural := 0;
      Roots                          : Root_Row_Vectors.Vector;
      Tree_Panel_Open       : Boolean := False;
      Tree_Panel_Scroll_Rows : Natural := 0;
      Tree_Rows             : Files.Folder_Tree.Visible_Row_Vectors.Vector;
      --  Copy to.../Move to... destination picker state driving the tree: when
      --  active the panel shows a Choose/Cancel bar, the title names the copy or
      --  move intent, and the row whose path equals Tree_Panel.Pick_Target is marked.
      Tree_Pick_Active      : Boolean := False;
      Tree_Pick_Moving      : Boolean := False;
      Tree_Pick_Target      : UString;
      --  The side panel has the keyboard: the row whose path equals
      --  Tree_Panel.Cursor is marked instead of the current folder.
      Tree_Keyboard_Active  : Boolean := False;
      Tree_Cursor           : UString;
      Breadcrumb_Segments   : Files.Breadcrumbs.Segment_Vectors.Vector;
      Command_Palette_Open           : Boolean := False;
      Command_Enabled                : Command_Enablement_Array := [others => False];
      Items                          : Item_Snapshot_Vectors.Vector;
      --  With group headers among the rows, the row each visible index is
      --  drawn at (Layouts.Row_Position_Of), so a reveal or a drag preview
      --  does not search the rows for it; empty without headers, where the
      --  row is the visible index. Part of the rows: kept and copied with
      --  Items.
      Visible_Rows                   : Row_Index_Vectors.Vector;
      Selected_Info                  : Info_Snapshot_Vectors.Vector;
      --  A multi-item selection's info, field by field, formatted once per
      --  build rather than twice per frame (Info_Sections_Built: present).
      Info_Sections                  : Coalesced_Section_Vectors.Vector;
      Info_Sections_Built            : Boolean := False;
      --  Combined size of the whole selection (selected files plus the recursive
      --  size of selected folders). Selection_Total_Pending is True while any
      --  selected folder is still being measured, so the total is not yet final.
      Selection_Total_Bytes          : Long_Long_Integer := 0;
      Selection_Total_Pending        : Boolean := False;
      --  What a build that keeps the rows may keep with them: the model's
      --  selection revision the rows' Selected flags show, and the selection
      --  and folder-size revisions the total above was summed at. A header
      --  change (a folder size streaming in, a palette keystroke) then walks
      --  neither the rows nor the selection again. Natural'Last: not known.
      Rows_Selection_Revision        : Natural := Natural'Last;
      Total_Selection_Revision       : Natural := Natural'Last;
      Total_Sizes_Revision           : Natural := Natural'Last;
      Context_Menu_Open              : Boolean := False;
      Context_Menu_Highlight         : Natural := 0;
      Context_Menu_X                 : Natural := 0;
      Context_Menu_Y                 : Natural := 0;
      Context_Menu_Target            : Files.UI_Types.Context_Menu_Target :=
        Files.UI_Types.Context_Menu_None;
      --  Detail-view column customization mirrored from settings so the pure
      --  layout functions can lay out only the visible columns, honour custom
      --  widths, and insert grouping bands without reaching back into settings.
      Detail_Columns_Visible         : Files.Preference_Types.Detail_Column_Visibility :=
        Files.Preference_Types.Default_Detail_Column_Visibility;
      Detail_Column_Widths           : Files.Preference_Types.Detail_Column_Widths :=
        Files.Preference_Types.Default_Detail_Column_Widths;
      Detail_Column_Order            : Files.Preference_Types.Detail_Column_Order :=
        Files.Preference_Types.Default_Detail_Column_Order;
      Group_By                       : Files.Preference_Types.Group_Mode := Files.Preference_Types.No_Grouping;
      --  Pending paste-conflict dialog: open when a paste/move is paused waiting
      --  for the user to resolve the colliding destination named Paste_Conflict_Name.
      Paste_Conflict_Open            : Boolean := False;
      Paste_Conflict_Name           : UString;
      Paste_Conflict_Apply_All      : Boolean := False;
      Paste_Progress                 : Paste_Progress_Snapshot;
      Quick_Look                     : Quick_Look_Snapshot;
      --  Color-label swatch picker overlay: open when the user is choosing a
      --  label for the current selection.
      Label_Picker_Open              : Boolean := False;
      Label_Picker_Highlight         : Positive := Files.UI_Types.Clear_Swatch;
   end record;

   --  Window layout geometry. Re-exported from Guikit.Draw so backends can
   --  consume it without depending on this package; existing
   --  Files.Rendering.Layout_Metrics references keep compiling unchanged.
   subtype Layout_Metrics is Guikit.Draw.Layout_Metrics;

   --  Deterministic set of one-based visible item indices. Used to carry the
   --  items a marquee (rubber-band) rectangle touches from the pure hit-test to
   --  the selection reducer.
   package Visible_Index_Vectors renames Guikit.Item_Grid.Visible_Index_Vectors;

   --  Clickable controls of the paste dialogs, recorded by the frame as it
   --  draws them: the conflict dialog's buttons, its apply-to-all toggle and
   --  its close button, and the progress panel's Cancel.
   type Dialog_Hit_Kind is
     (Dialog_Hit_None,
      Dialog_Hit_Replace,
      Dialog_Hit_Skip,
      Dialog_Hit_Rename,
      Dialog_Hit_Cancel,
      Dialog_Hit_Apply_All,
      Dialog_Hit_Conflict_Close,
      Dialog_Hit_Progress_Cancel);

   type Dialog_Hit_Region is record
      Kind   : Dialog_Hit_Kind := Dialog_Hit_None;
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;

   package Dialog_Hit_Region_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Dialog_Hit_Region);

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
      Theme_Palette : Guikit.Draw.Theme_Kind := Guikit.Draw.Theme_Dark;
      Rectangles    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Triangles     : Guikit.Draw.Triangle_Command_Vectors.Vector;
      Text          : Guikit.Draw.Text_Command_Vectors.Vector;
      Icons         : Guikit.Draw.Icon_Command_Vectors.Vector;
      Overlay_Rectangles : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Overlay_Text       : Guikit.Draw.Text_Command_Vectors.Vector;
      Tooltips      : Guikit.Draw.Tooltip_Command_Vectors.Vector;
      Accessibility : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Permission_Hits : Permission_Hit_Region_Vectors.Vector;
      Ownership_Hits : Ownership_Hit_Region_Vectors.Vector;
      Dialog_Hits : Dialog_Hit_Region_Vectors.Vector;
   end record;

   --  The rectangle that dims the whole window under a modal panel: what the
   --  frame builder and the window layer both lay under one.
   --
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @return The backdrop, in the modal backdrop colour.
   function Modal_Backdrop (Width, Height : Natural) return Guikit.Draw.Rectangle_Command is
     ((X => 0, Y => 0, Width => Width, Height => Height, Color => Guikit.Draw.Modal_Backdrop_Color));

   --  Whether Snapshot shows Overlay open: the snapshot's own flag for each
   --  Files.UI_Types.Input_Overlay.
   --
   --  @param Snapshot Snapshot to inspect.
   --  @param Overlay The overlay asked about.
   --  @return True when the snapshot has Overlay open.
   function Overlay_Open
     (Snapshot : View_Snapshot;
      Overlay  : Files.UI_Types.Input_Overlay)
      return Boolean is
     (case Overlay is
         when Files.UI_Types.Settings_Pane_Overlay   => Snapshot.Settings_Pane_Open,
         when Files.UI_Types.Command_Palette_Overlay => Snapshot.Command_Palette_Open,
         when Files.UI_Types.Root_Selector_Overlay   => Snapshot.Root_Selector_Open,
         when Files.UI_Types.Sort_Menu_Overlay       => Snapshot.Sort_Menu_Open,
         when Files.UI_Types.Context_Menu_Overlay    => Snapshot.Context_Menu_Open,
         when Files.UI_Types.Label_Picker_Overlay    => Snapshot.Label_Picker_Open,
         when Files.UI_Types.Quick_Look_Overlay      => Snapshot.Quick_Look.Open,
         when Files.UI_Types.Tree_Pick_Overlay       => Snapshot.Tree_Pick_Active,
         when Files.UI_Types.Paste_Conflict_Overlay  => Snapshot.Paste_Conflict_Open,
         when Files.UI_Types.Foreground_Job_Overlay  => Snapshot.Paste_Progress.Open);

   --  Where the open overlay on top in Snapshot stands in
   --  Files.UI_Types.Overlay_Stack: the first open one, as
   --  Files.Model.Topmost_Overlay finds it in the model the snapshot was
   --  built from.
   --
   --  @param Snapshot Snapshot to inspect.
   --  @return Its index in Files.UI_Types.Overlay_Stack, or 0 when none is open.
   function Topmost_Overlay_Position (Snapshot : View_Snapshot) return Natural;

   --  How many selected items the info pane lists in detail
   --  (Files.UI_Types.Max_Info_Items).
   Max_Info_Items : constant := Files.UI_Types.Max_Info_Items;

   --  Build an immutable view snapshot with loaded settings summary data, as
   --  of the clock now.
   --
   --  @param Model Source window model.
   --  @param Settings Loaded settings model.
   --  @return Immutable snapshot safe for rendering.
   function Build_Snapshot
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return View_Snapshot;

   --  Build_Snapshot into Snapshot in place, which spares a large folder's
   --  snapshot the two copies a function result costs.
   --
   --  @param Snapshot Rebuilt; with Keep_Rows its rows are kept.
   --  @param Model Source window model.
   --  @param Settings Settings model.
   --  @param Now The wall-clock time it shows the folder at; it keeps the
   --    start of that minute (Files.Timing.Minute_Start).
   --  @param Keep_Rows Snapshot's rows are still right but for which are
   --    selected (Files.Model.Rows_Revision has not moved since they were
   --    built): only their selected flags are set.
   procedure Build_Snapshot_Into
     (Snapshot  : in out View_Snapshot;
      Model     : Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Now       : Ada.Calendar.Time;
      Keep_Rows : Boolean := False);

   --  Give Target Source's rows and what is kept with them (the row of each
   --  visible index, the selection their flags show, the selection total
   --  and what it was summed at), for a Build_Snapshot_Into that keeps the
   --  rows into another snapshot than the one they were built in.
   --
   --  @param Target Snapshot to build into next, with Keep_Rows.
   --  @param Source Snapshot whose rows are still right.
   procedure Copy_Rows (Target : in out View_Snapshot; Source : View_Snapshot);

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

   --  Where the pointer is and what it is doing, as a frame draws it: the
   --  hover highlight and tooltips, the pressed control, a dragged item's
   --  preview -- all at the one pointer position -- and the marquee
   --  rectangle. In framebuffer pixels; Has_Hover says whether the position
   --  means anything, Marquee_Active whether the rectangle does. A control
   --  is drawn pressed only while the pointer is on it and the press began on
   --  it (Press_X, Press_Y): a drag that crosses buttons presses none.
   type Pointer_State is record
      Hover_X         : Natural := 0;
      Hover_Y         : Natural := 0;
      Has_Hover       : Boolean := False;
      --  A button is held down at the pointer, pressed where Press_X/Y say.
      Pressed         : Boolean := False;
      Press_X         : Natural := 0;
      Press_Y         : Natural := 0;
      --  An item is being dragged with the pointer: its visible index.
      Dragging        : Boolean := False;
      Drag_Item_Index : Natural := 0;
      Marquee_Active  : Boolean := False;
      Marquee_X       : Natural := 0;
      Marquee_Y       : Natural := 0;
      Marquee_W       : Natural := 0;
      Marquee_H       : Natural := 0;
   end record;

   --  No pointer in the window.
   No_Pointer : constant Pointer_State := (others => <>);

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
   --  @param Pointer Where the pointer is and what it is doing.
   --  @return Frame command list for a renderer backend.
   function Build_Frame_Commands
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive;
      Pointer     : Pointer_State := No_Pointer)
      return Frame_Commands;

   --  The Details rows' cell texts and accessibility descriptions a window
   --  has formatted, kept across the frames drawn from one snapshot build: a
   --  pointer move rebuilds the frame but not the snapshot, so the rows it
   --  draws again need not be humanized and localized again. Only drawn rows
   --  are formatted, and only once a build: the rows a snapshot keeps across
   --  a new minute (relative times) or a column drag (descriptions) belong
   --  to a new build, so they are never baked into the snapshot itself.
   type Row_Text_Cache is private;

   --  Build_Frame_Commands with the window's row texts: those formatted for
   --  the same build are read back, the rest formatted and kept.
   --
   --  @param Snapshot View snapshot to render.
   --  @param Build Which build Snapshot is (Files.Application.Snapshot_Slots.Slot_Contents):
   --    equal numbers mean equal contents but for the scroll offsets, which
   --    the row texts do not depend on.
   --  @param Row_Texts The window's cache; cleared when Build moves.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @param Pointer Where the pointer is and what it is doing.
   --  @return Frame command list for a renderer backend.
   function Build_Frame_Commands
     (Snapshot    : View_Snapshot;
      Build       : Natural;
      Row_Texts   : in out Row_Text_Cache;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive;
      Pointer     : Pointer_State := No_Pointer)
      return Frame_Commands;

   --  How many rows Row_Texts holds formatted (for tests).
   --
   --  @param Row_Texts A window's cache.
   --  @return The number of rows formatted for its build.
   function Formatted_Rows (Row_Texts : Row_Text_Cache) return Natural;

   --  The text line height for a font pixel size.
   --
   --  @param Size Font pixel size.
   --  @return Line height, the text cell height, in pixels.
   function Cell_Height_For (Size : Positive) return Positive is
     (Positive'Max (1, Size * 5 / 4));

private

   --  One text per details column: the column names a row's accessibility
   --  description repeats, or one row's cells.
   type Detail_Column_Texts is array (Files.Preference_Types.Detail_Column) of UString;

   --  One drawn row's texts.
   type Row_Texts_Entry is record
      Cells       : Detail_Column_Texts;
      Description : UString;
   end record;

   function Hash_Row (Index : Positive) return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type'Mod (Index));

   --  By the row's index in the snapshot's items: a handful of drawn rows,
   --  so clearing it when the build moves costs nothing in a large folder.
   package Row_Text_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Positive,
      Element_Type    => Row_Texts_Entry,
      Hash            => Hash_Row,
      Equivalent_Keys => "=");

   type Row_Text_Cache is record
      --  The build the rows were formatted for; 0 never matches a build.
      Build : Natural := 0;
      Rows  : Row_Text_Maps.Map;
   end record;

   function Formatted_Rows (Row_Texts : Row_Text_Cache) return Natural is
     (Natural (Row_Texts.Rows.Length));

   --  The text cell width is the advance every layout measures labels with,
   --  taken from the same line height. Derived separately (Size * 3 / 4) it
   --  came out a pixel wider at some sizes, so labels sized to fit lost their
   --  last character and large fonts read "Klei", "Gro", "hom".
   --
   --  @param Size Font pixel size.
   --  @return Text cell width in pixels.
   function Cell_Width_For (Size : Positive) return Positive is
     (Guikit.Layout.Caret_Advance_Width (Cell_Height_For (Size)));

   --  The index of the first overlay of Files.UI_Types.Overlay_Stack open in
   --  Snapshot, looking from From down.
   --
   --  @param Snapshot Snapshot to inspect.
   --  @param From Index in Files.UI_Types.Overlay_Stack to start at.
   --  @return The index found, or 0 when none from From is open.
   function First_Open_Overlay (Snapshot : View_Snapshot; From : Positive) return Natural is
     (if From > Files.UI_Types.Overlay_Stack'Last then 0
      elsif Overlay_Open (Snapshot, Files.UI_Types.Overlay_Stack (From)) then From
      else First_Open_Overlay (Snapshot, From + 1));

   function Topmost_Overlay_Position (Snapshot : View_Snapshot) return Natural is
     (First_Open_Overlay (Snapshot, Files.UI_Types.Overlay_Stack'First));

end Files.Rendering;
