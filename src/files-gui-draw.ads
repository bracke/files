with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Interfaces;
with System;

--  Renderer-agnostic draw model.
--
--  This package holds the generic visual primitives a frame is built from
--  (colors, rectangles, text, icons, glyphs, accessibility nodes) together
--  with the pure helpers that resolve palette colors and parse bundled icon
--  assets. It has no dependency on any file-manager domain package, so the
--  renderer and its backends can share these types without coupling to the
--  application model.
package Files.Gui.Draw is
   --  Unbounded text used by draw-model records. Defined here so the draw model
   --  stays independent of any application domain package.
   subtype UString is Ada.Strings.Unbounded.Unbounded_String;

   --  Raw pixel/byte buffer for thumbnails carried in draw commands. Defined
   --  here to keep the draw model self-contained; the application re-exports
   --  this instance as Files.Types.Byte_Vectors.
   package Byte_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Interfaces.Unsigned_8,
      "="          => Interfaces."=");

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
      Favorite_Star_Color,
      Label_Red_Color,
      Label_Orange_Color,
      Label_Yellow_Color,
      Label_Green_Color,
      Label_Blue_Color,
      Label_Purple_Color,
      Label_Gray_Color,
      Marquee_Color,
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
      Thumbnail_Pixels : Byte_Vectors.Vector;
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
      Role_Heading,
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

   --  Stable window layout geometry shared by the renderer and its backends.
   --
   --  Pure pixel measurements (widths, heights, and pane origins) with no
   --  dependency on any application domain type, so a rendering backend can
   --  normalize frame coordinates without coupling to Files.Rendering.
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

   --  Outcome of rasterizing a frame's text through the textrender backend.
   type Text_Render_Status is
     (Text_Render_Success,
      Text_Render_Font_Load_Failed,
      Text_Render_Font_Not_Loaded,
      Text_Render_Glyph_Failed);

   --  Glyph geometry and atlas upload data produced for a frame's text.
   --
   --  Carries the primary and overlay glyph quads together with the shared
   --  text-atlas pixels a backend uploads. Defined here so a rendering backend
   --  can consume the result without depending on Files.Rendering.
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

end Files.Gui.Draw;
