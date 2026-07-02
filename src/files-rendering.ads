with Ada.Calendar;
with Ada.Containers.Vectors;
with System;

with Files.Breadcrumbs;
with Files.Commands;
with Files.File_System;
with Files.Folder_Tree;
with Files.Model;
with Files.Settings;
with Files.Types;

--  Immutable render snapshots and layout calculations.
package Files.Rendering is
   subtype UString is Files.Types.UString;

   type Render_Color is
     (Canvas_Color,
      Toolbar_Color,
      Bottom_Bar_Color,
      Main_Color,
      Detail_Alternate_Color,
      Pane_Color,
      Input_Color,
      Input_Error_Color,
      Selection_Color,
      Hover_Color,
      Pressed_Color,
      Border_Color,
      Text_Color,
      Muted_Text_Color,
      Error_Text_Color,
      Disabled_Text_Color,
      Icon_Directory_Color,
      Icon_File_Color,
      Icon_Executable_Color,
      Icon_Unknown_Color,
      Overlay_Color);

   --  Selectable color palettes. Theme_Dark is the default. Theme_High_Contrast
   --  keeps the dark base color values (its extra emphasis is applied through
   --  Render_Theme) and takes precedence over Theme_Light when both the
   --  high-contrast and light preferences are enabled.
   type Theme_Kind is (Theme_Dark, Theme_Light, Theme_High_Contrast);

   --  Resolved sRGB color with straight alpha. Channels are in 0.0 .. 1.0.
   type Palette_Color is record
      R : Float := 0.0;
      G : Float := 0.0;
      B : Float := 0.0;
      A : Float := 1.0;
   end record;

   --  Return the sRGB color a role resolves to under a palette theme.
   --
   --  @param Role Semantic color role to resolve.
   --  @param Theme Active palette theme.
   --  @return sRGB channel values (0.0 .. 1.0) with straight alpha.
   function Color_For
     (Role  : Render_Color;
      Theme : Theme_Kind := Theme_Dark)
      return Palette_Color;

   type Item_Snapshot is record
      Name               : UString;
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
      Filetype_Extra     : UString;
      Thumbnail_Available : Boolean := False;
      Thumbnail_Path      : UString;
      Thumbnail_Width     : Natural := 0;
      Thumbnail_Height    : Natural := 0;
      Thumbnail_Pixels    : Files.Types.Byte_Vectors.Vector;
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
      Owner_Id           : Natural := 0;
      Group_Id           : Natural := 0;
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

   type Command_Result_Snapshot is record
      Identifier : UString;
      Label      : UString;
      Description : UString;
      Shortcut_Text : UString;
      Enabled    : Boolean := False;
      Selected   : Boolean := False;
   end record;

   package Command_Result_Snapshot_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Command_Result_Snapshot);

   type Command_Enablement_Array is array (Files.Commands.Registered_Command_Id) of Boolean;

   type View_Snapshot is record
      Current_Path         : UString;
      View_Mode            : Files.Types.View_Mode := Files.Types.Small_Icons;
      Sort_Field           : Files.Model.Sort_Field := Files.Model.Sort_Name;
      Sort_Ascending       : Boolean := True;
      Sort_Menu_Open       : Boolean := False;
      Item_Count           : Natural := 0;
      Visible_Count        : Natural := 0;
      Hidden_Count         : Natural := 0;
      Selected_Count        : Natural := 0;
      Free_Space_Known      : Boolean := False;
      Free_Space_Bytes      : Long_Long_Integer := 0;
      Total_Space_Bytes     : Long_Long_Integer := 0;
      Filter_Text           : UString;
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
      Settings_Default_View       : UString;
      Settings_Default_View_Token : UString;
      Settings_Hidden_Files       : UString;
      Settings_Hidden_Files_Token : UString;
      Settings_Sort               : UString;
      Settings_Sort_Field_Token   : UString;
      Settings_Sort_Ascending       : UString;
      Settings_Sort_Ascending_Token : UString;
      Settings_Theme                : UString;
      Settings_Theme_Token          : UString;
      Settings_Icon_Theme           : UString;
      Settings_Font_Pixel_Size      : UString;
      Settings_Filetypes            : UString;
      Settings_Icons                : UString;
      Settings_Open_Actions         : UString;
      Settings_Filetype_Extension : UString;
      Settings_Filetype_Value : UString;
      Settings_Icon_Filetype : UString;
      Settings_Icon_Value    : UString;
      Settings_Open_Action_Token : UString;
      Settings_Open_Action_Command : UString;
      Settings_Control_Options : UString;
      Settings_Field_Help  : UString;
      Settings_Field_Index  : Natural := 0;
      Settings_Draft_Valid  : Boolean := True;
      Settings_Draft_Error  : UString;
      Settings_Can_Save     : Boolean := False;
      Settings_Can_Reset    : Boolean := False;
      Theme_Name            : UString;
      Theme_High_Contrast   : Boolean := False;
      Theme_Palette         : Theme_Kind := Theme_Dark;
      Theme_Focus_Ring      : Render_Color := Border_Color;
      Info_Pane_Scroll_Lines : Natural := 0;
      Settings_Pane_Scroll_Lines : Natural := 0;
      Main_View_Scroll_Lines : Natural := 0;
      Root_Selector_Open    : Boolean := False;
      Root_Selected_Index   : Natural := 0;
      Root_Paths                     : Files.Types.String_Vectors.Vector;
      Root_Labels                    : Files.Types.String_Vectors.Vector;
      Tree_Panel_Open       : Boolean := False;
      Tree_Rows             : Files.Folder_Tree.Visible_Row_Vectors.Vector;
      --  Copy to.../Move to... destination picker state driving the tree: when
      --  active the panel shows a Choose/Cancel bar, the title names the copy or
      --  move intent, and the row whose path equals Tree_Pick_Target is marked.
      Tree_Pick_Active      : Boolean := False;
      Tree_Pick_Moving      : Boolean := False;
      Tree_Pick_Target      : UString;
      Breadcrumb_Segments   : Files.Breadcrumbs.Segment_Vectors.Vector;
      Command_Palette_Open           : Boolean := False;
      Command_Palette_Query          : UString;
      Command_Palette_Selected_Index : Natural := 0;
      Command_Palette_Result_Offset  : Natural := 0;
      Command_Enabled                : Command_Enablement_Array := [others => False];
      Command_Palette_Results        : Command_Result_Snapshot_Vectors.Vector;
      Items                          : Item_Snapshot_Vectors.Vector;
      Selected_Info                  : Info_Snapshot_Vectors.Vector;
      Context_Menu_Open              : Boolean := False;
      Context_Menu_X                 : Natural := 0;
      Context_Menu_Y                 : Natural := 0;
      Context_Menu_Target            : Files.Model.Context_Menu_Target :=
        Files.Model.Context_Menu_None;
      Context_Menu_Item_Index        : Natural := 0;
      --  Detail-view column customization mirrored from settings so the pure
      --  layout functions can lay out only the visible columns, honour custom
      --  widths, and insert grouping bands without reaching back into settings.
      Detail_Columns_Visible         : Files.Types.Detail_Column_Visibility :=
        Files.Types.Default_Detail_Column_Visibility;
      Detail_Column_Widths           : Files.Types.Detail_Column_Widths :=
        Files.Types.Default_Detail_Column_Widths;
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
   end record;

   --  A context-menu row is either a selectable command or a non-selectable
   --  divider that visually groups the commands above and below it.
   type Context_Menu_Row_Kind is (Command_Row, Separator_Row);

   --  Real commands plus the separators that group them. The item menu carries
   --  11 commands split into 4 groups by 3 separators (14 rows); the constant
   --  keeps headroom so the fixed arrays never overflow.
   Max_Context_Menu_Rows : constant := 15;
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

   --  Return the row index at a window coordinate, or zero when outside.
   --
   --  @param Menu Layout returned by Calculate_Context_Menu_Layout.
   --  @param X Window X coordinate.
   --  @param Y Window Y coordinate.
   --  @return Row index between 1 and Row_Count, or 0 when outside the menu.
   function Context_Menu_Row_At
     (Menu : Context_Menu_Layout;
      X    : Natural;
      Y    : Natural)
      return Natural;

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

   type Layout_Metrics is record
      Width             : Natural := 0;
      Height            : Natural := 0;
      Toolbar_Height    : Natural := 0;
      Bottom_Bar_Height : Natural := 0;
      Main_X            : Natural := 0;
      Main_Y            : Natural := 0;
      Main_Width        : Natural := 0;
      Main_Height       : Natural := 0;
      Info_Pane_Width   : Natural := 0;
      Command_X         : Natural := 0;
      Command_Y         : Natural := 0;
      Command_Width     : Natural := 0;
      Command_Height    : Natural := 0;
   end record;

   type Item_Layout is record
      Visible_Index : Natural := 0;
      X             : Natural := 0;
      Y             : Natural := 0;
      Width         : Natural := 0;
      Height        : Natural := 0;
      Icon_X        : Natural := 0;
      Icon_Y        : Natural := 0;
      Icon_Size     : Natural := 0;
      Text_X         : Natural := 0;
      Text_Y         : Natural := 0;
      Text_Width     : Natural := 0;
      Name_X         : Natural := 0;
      Name_Width     : Natural := 0;
      Modified_X     : Natural := 0;
      Modified_Width : Natural := 0;
      Size_X         : Natural := 0;
      Size_Width     : Natural := 0;
      Filetype_X     : Natural := 0;
      Filetype_Width : Natural := 0;
      Created_X         : Natural := 0;
      Created_Width     : Natural := 0;
      Permissions_X     : Natural := 0;
      Permissions_Width : Natural := 0;
   end record;

   package Item_Layout_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Item_Layout);

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
   end record;

   type Command_Palette_Layout is record
      X              : Natural := 0;
      Y              : Natural := 0;
      Width          : Natural := 0;
      Height         : Natural := 0;
      Search_X       : Natural := 0;
      Search_Y       : Natural := 0;
      Search_Width   : Natural := 0;
      Search_Height  : Natural := 0;
      Results_X      : Natural := 0;
      Results_Y      : Natural := 0;
      Results_Width  : Natural := 0;
      Results_Height : Natural := 0;
      Row_Height     : Natural := 0;
   end record;

   type Command_Result_Layout is record
      Result_Index : Natural := 0;
      X            : Natural := 0;
      Y            : Natural := 0;
      Width        : Natural := 0;
      Height       : Natural := 0;
      Selected     : Boolean := False;
      Enabled      : Boolean := False;
   end record;

   package Command_Result_Layout_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Command_Result_Layout);

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

   type Tree_Panel_Layout is record
      X          : Natural := 0;
      Y          : Natural := 0;
      Width      : Natural := 0;
      Height     : Natural := 0;
      Row_Height : Natural := 0;
   end record;

   type Tree_Row_Layout is record
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

   type Render_Theme is record
      Name             : UString;
      High_Contrast    : Boolean := False;
      Selection_Strong : Boolean := False;
      Focus_Ring       : Render_Color := Border_Color;
      Warning_Color    : Render_Color := Error_Text_Color;
   end record;

   type Accessibility_Profile is record
      Keyboard_Navigation : Boolean := True;
      Focus_Rings         : Boolean := True;
      High_Contrast       : Boolean := False;
      Tooltips            : Boolean := True;
      Text_Truncation     : Boolean := True;
      Screen_Reader_Role_Metadata : Boolean := False;
   end record;

   type Accessibility_Integration_Profile is record
      Render_Node_Tree        : Boolean := True;
      Native_API_Binding_Status : Files.File_System.Native_API_Binding_Status :=
        Files.File_System.Native_API_Binding_Missing;
      Role_Metadata           : Boolean := True;
      Table_Metadata          : Boolean := True;
      Pane_Section_Metadata   : Boolean := True;
      Keyboard_Focus_Metadata : Boolean := True;
      Binding_Unit            : UString;
   end record;

   type Settings_Editor_Profile is record
      Scalar_Controls       : Natural := 0;
      Mapping_Controls      : Natural := 0;
      Open_Action_Controls  : Natural := 0;
      Supports_Save         : Boolean := True;
      Supports_Reset        : Boolean := True;
      Per_Field_Diagnostics : Boolean := True;
      Supports_Option_Cycling : Boolean := True;
      Supports_Add_Remove_Mapping : Boolean := True;
      Supports_Draft_Validation : Boolean := True;
      Saves_Central_Settings : Boolean := True;
   end record;

   type Icon_Theme_Profile is record
      Theme_Name          : UString;
      Placeholder_Icons   : Boolean := True;
      Scalable_Icons      : Boolean := False;
      Filetype_Icons      : Natural := 0;
      Asset_Directory     : UString;
      Asset_Format        : UString;
      User_Selectable     : Boolean := False;
      High_Contrast_Ready : Boolean := False;
   end record;

   --  Return the default render theme metadata.
   --
   --  @return Theme metadata used by the first implementation.
   function Default_Theme return Render_Theme;

   --  Return high-contrast render theme metadata.
   --
   --  @return Theme metadata for accessibility-oriented rendering.
   function High_Contrast_Theme return Render_Theme;

   --  Return accessibility metadata for the default renderer profile.
   --
   --  @return Accessibility feature flags for the renderer.
   function Default_Accessibility_Profile return Accessibility_Profile;

   --  Return accessibility metadata for the high-contrast renderer profile.
   --
   --  @return Accessibility feature flags for the high-contrast renderer.
   function High_Contrast_Accessibility_Profile return Accessibility_Profile;

   --  Return accessibility tree and native API integration metadata.
   --
   --  @return Accessibility integration feature flags for the renderer.
   function Accessibility_Integration_Profile_Of_Current_UI
      return Accessibility_Integration_Profile;

   --  Return settings editor control metadata for the current UI.
   --
   --  @return Settings editor profile.
   function Settings_Editor_Profile_Of_Current_UI return Settings_Editor_Profile;

   --  Return icon theme metadata for the current renderer.
   --
   --  @return Icon theme profile.
   function Icon_Theme_Profile_Of_Current_UI return Icon_Theme_Profile;

   --  Return icon theme metadata selected by Settings.
   --
   --  @param Settings Settings model containing the selected icon theme.
   --  @return Icon theme profile for the configured theme.
   function Icon_Theme_Profile_For
     (Settings : Files.Settings.Settings_Model)
      return Icon_Theme_Profile;

   --  Return bundled icon asset identifiers declared by the current renderer.
   --
   --  @return Vector containing one icon identifier for each bundled icon asset.
   function Bundled_Icon_Asset_Names return Files.Types.String_Vectors.Vector;

   type Icon_Asset_Color_Role is
     (Icon_Asset_Base,
      Icon_Asset_Accent,
      Icon_Asset_Border,
      Icon_Asset_Muted);

   type Icon_Asset_Rect is record
      Grid_X : Natural := 0;
      Grid_Y : Natural := 0;
      Grid_W : Natural := 0;
      Grid_H : Natural := 0;
      Role   : Icon_Asset_Color_Role := Icon_Asset_Base;
   end record;

   package Icon_Asset_Rect_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Icon_Asset_Rect);

   type Icon_Asset is record
      Valid      : Boolean := False;
      Name       : UString;
      Grid       : Positive := 16;
      Rectangles : Icon_Asset_Rect_Vectors.Vector;
   end record;

   --  Return bundled files-icon-v1 asset text for an icon and theme.
   --
   --  @param Icon_Id Bundled icon identifier.
   --  @param Theme_Name Icon theme identifier.
   --  @return Icon asset text, or an empty string when no bundled asset exists.
   function Icon_Asset_Text
     (Icon_Id    : String;
      Theme_Name : String)
      return String;

   --  Parse a files-icon-v1 asset into rasterizable rectangle commands.
   --
   --  @param Content Icon asset text.
   --  @return Parsed icon asset; Valid is False when the text is malformed.
   function Parse_Icon_Asset
     (Content : String)
      return Icon_Asset;

   type Rectangle_Command is record
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
      Color  : Render_Color := Canvas_Color;
   end record;

   package Rectangle_Command_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Rectangle_Command);

   type Triangle_Command is record
      X1    : Float := 0.0;
      Y1    : Float := 0.0;
      X2    : Float := 0.0;
      Y2    : Float := 0.0;
      X3    : Float := 0.0;
      Y3    : Float := 0.0;
      Color : Render_Color := Canvas_Color;
   end record;

   package Triangle_Command_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Triangle_Command);

   type Text_Command is record
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
      Text   : UString;
      Color  : Render_Color := Text_Color;
      Truncated : Boolean := False;
      Scale_To_Box : Boolean := False;
      Italic : Boolean := False;
   end record;

   package Text_Command_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Text_Command);

   type Tooltip_Command is record
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
      Text   : UString;
   end record;

   package Tooltip_Command_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Tooltip_Command);

   type Icon_Command is record
      X          : Natural := 0;
      Y          : Natural := 0;
      Size       : Natural := 0;
      Icon_Id    : UString;
      Theme_Name : UString;
      Asset_Path : UString;
      Thumbnail_Width  : Natural := 0;
      Thumbnail_Height : Natural := 0;
      Thumbnail_Pixels : Files.Types.Byte_Vectors.Vector;
   end record;

   package Icon_Command_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Icon_Command);

   type Accessibility_Role is
     (Role_Window,
      Role_Toolbar,
      Role_Button,
      Role_Text_Input,
      Role_List,
      Role_List_Item,
      Role_Table,
      Role_Table_Row,
      Role_Pane,
      Role_Dialog,
      Role_Status);

   type Accessibility_Node is record
      Role        : Accessibility_Role := Role_Pane;
      X           : Natural := 0;
      Y           : Natural := 0;
      Width       : Natural := 0;
      Height      : Natural := 0;
      Name        : UString;
      Description : UString;
      Enabled     : Boolean := True;
      Selected    : Boolean := False;
      Focused     : Boolean := False;
   end record;

   package Accessibility_Node_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Accessibility_Node);

   type Settings_Hit_Kind is
     (Settings_Hit_None,
      Settings_Hit_Field,
      Settings_Hit_Reset,
      Settings_Hit_Add,
      Settings_Hit_Remove,
      Settings_Hit_Segment,
      Settings_Hit_Toggle,
      Settings_Hit_Stepper_Down,
      Settings_Hit_Stepper_Up);

   type Settings_Hit_Region is record
      Kind   : Settings_Hit_Kind := Settings_Hit_None;
      Field  : Natural := 0;
      Option : Natural := 0;
      X      : Natural := 0;
      Y      : Natural := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;

   package Settings_Hit_Region_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Settings_Hit_Region);

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
      Settings_Hits : Settings_Hit_Region_Vectors.Vector;
      Permission_Hits : Permission_Hit_Region_Vectors.Vector;
      Ownership_Hits : Ownership_Hit_Region_Vectors.Vector;
      Conflict_Hits : Conflict_Hit_Region_Vectors.Vector;
   end record;

   --  Return the settings-pane hit region containing a point, if any.
   --
   --  @param Frame Frame whose settings hit regions are tested.
   --  @param X Point X coordinate in pixels.
   --  @param Y Point Y coordinate in pixels.
   --  @return The hit region at the point, or an empty region when none match.
   function Settings_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Settings_Hit_Region;

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

   --  Return the paste-conflict-dialog control containing a point, if any.
   --
   --  @param Frame Frame whose conflict hit regions are tested.
   --  @param X Point X coordinate in pixels.
   --  @param Y Point Y coordinate in pixels.
   --  @return The control at the point, or a region with Kind Conflict_Hit_None.
   function Conflict_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Conflict_Hit_Region;

   --  Return the info-pane permission cell containing a point, if any.
   --
   --  @param Frame Frame whose permission hit regions are tested.
   --  @param X Point X coordinate in pixels.
   --  @param Y Point Y coordinate in pixels.
   --  @return The cell at the point, or a region with Present False when none.
   function Permission_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Permission_Hit_Region;

   --  Return the info-pane ownership value containing a point, if any.
   --
   --  @param Frame Frame whose ownership hit regions are tested.
   --  @param X Point X coordinate in pixels.
   --  @param Y Point Y coordinate in pixels.
   --  @return The value at the point, or a region with Present False when none.
   function Ownership_Hit_At
     (Frame : Frame_Commands;
      X     : Natural;
      Y     : Natural)
      return Ownership_Hit_Region;

   type Text_Renderer is private;

   type Text_Render_Status is
     (Text_Render_Success,
      Text_Render_Font_Load_Failed,
      Text_Render_Font_Not_Loaded,
      Text_Render_Glyph_Failed);

   type Glyph_Command is record
      X         : Float := 0.0;
      Y         : Float := 0.0;
      Width     : Float := 0.0;
      Height    : Float := 0.0;
      U0        : Float := 0.0;
      V0        : Float := 0.0;
      U1        : Float := 0.0;
      V1        : Float := 0.0;
      Color     : Render_Color := Text_Color;
      Codepoint : Natural := 0;
   end record;

   package Glyph_Command_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Glyph_Command);

   type Text_Render_Result is record
      Status       : Text_Render_Status := Text_Render_Font_Not_Loaded;
      Glyphs       : Glyph_Command_Vectors.Vector;
      Overlay_Glyphs : Glyph_Command_Vectors.Vector;
      Missing_Glyph_Count : Natural := 0;
      Atlas_Width  : Natural := 0;
      Atlas_Height : Natural := 0;
      Atlas_Pixels : System.Address := System.Null_Address;
      Atlas_Bytes  : Natural := 0;
      Atlas_Dirty  : Boolean := False;
   end record;

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
   --  @return Item layout rectangles in visible-item order.
   function Calculate_Item_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
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

   --  Return the visible item index at a position.
   --
   --  @param Items Item layout rectangles.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @return Visible item index, or zero when no item is hit.
   function Item_At
     (Items : Item_Layout_Vectors.Vector;
      X     : Natural;
      Y     : Natural)
      return Natural;

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

   --  Return the sort command for a details header click.
   --
   --  @param Snapshot Immutable view snapshot.
   --  @param Layout Calculated frame layout.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @param Line_Height Text line height in pixels.
   --  @return Sort command for the clicked details header column, or No_Command.
   function Details_Header_Command_At
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Files.Commands.Command_Id;

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

   --  Hit-test a details-header coordinate against the draggable column
   --  separators. Every visible optional column carries a separator on its left
   --  edge (the boundary shared with the column to its left); dragging that
   --  separator resizes the optional column. The separator hot zone takes
   --  precedence over the header cell's sort click, so a press on a separator
   --  begins a resize instead of changing the sort field. Returns a separator
   --  with Present False when the coordinate lies outside every hot zone, the
   --  header band, or the details view.
   --
   --  @param Snapshot Immutable view snapshot.
   --  @param Layout Calculated frame layout.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @param Line_Height Text line height in pixels.
   --  @return The separator under the coordinate, or one with Present False.
   function Details_Header_Separator_At
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Detail_Column_Separator;

   --  Calculate command-palette search and result-section rectangles.
   --
   --  @param Layout High-level window layout metrics.
   --  @param Line_Height Text line height in pixels.
   --  @return Command-palette layout rectangles.
   function Calculate_Command_Palette_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Command_Palette_Layout;

   --  Calculate command-palette result row rectangles.
   --
   --  @param Snapshot View snapshot containing command-palette results.
   --  @param Layout Command-palette layout metrics.
   --  @return Result row rectangles in palette result order.
   function Calculate_Command_Result_Layout
     (Snapshot : View_Snapshot;
      Layout   : Command_Palette_Layout)
      return Command_Result_Layout_Vectors.Vector;

   --  Return the command-palette result index at a position.
   --
   --  @param Rows Command-palette result row layouts.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @return Result index, or zero when no result row is hit.
   function Command_Result_At
     (Rows : Command_Result_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural;

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

   --  Return the root path index at a position.
   --
   --  @param Rows Root-selector row layouts.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @return Root path index, or zero when no root row is hit.
   function Root_Path_At
     (Rows : Root_Path_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural;

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

   --  Return the breadcrumb segment index at a position, or zero.
   --
   --  @param Rows Breadcrumb segment rectangles.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @return One-based segment index of a clickable segment, or zero.
   function Breadcrumb_At
     (Rows : Breadcrumb_Segment_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
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

   --  Return the tree node index whose row contains a position, or zero.
   --
   --  @param Rows Tree row rectangles.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @return One-based tree node index, or zero when no row is hit.
   function Tree_Row_At
     (Rows : Tree_Row_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural;

   --  Return the tree node index whose expander triangle contains a position.
   --
   --  @param Rows Tree row rectangles.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @return One-based node index when an expander triangle is hit, else zero.
   function Tree_Triangle_At
     (Rows : Tree_Row_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural;

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
      Has_Drag    : Boolean := False)
      return Frame_Commands;

   --  Return the first known monospace TrueType font available on the system.
   --
   --  @return Font path, or an empty string when no known font is present.
   function Default_Font_Path return String;

   --  Return a font path selected for all text currently present in a frame.
   --
   --  @param Frame Frame commands whose text should render directly.
   --  @return Font path, or an empty string when no known font is present.
   function Font_Path_For_Frame
     (Frame : Frame_Commands)
      return String;

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
   type Text_Renderer is record
      Loaded       : Boolean := False;
      Font_Path    : UString;
      Cell_Width   : Positive := 10;
      Cell_Height  : Positive := 20;
      Atlas_Width  : Positive := 1024;
      Atlas_Height : Positive := 1024;
   end record;

end Files.Rendering;
