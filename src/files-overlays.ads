with Guikit.Draw;

with Files.Model;

--  Drawing the window's stateful overlays -- the command palette and the
--  settings panel -- from the state the model holds for them. The window
--  layer merges what this draws over the cached frame (Append_Overlay); the
--  model itself draws nothing and localizes nothing for them.
package Files.Overlays is

   --  Draw the command palette within a region.
   --
   --  @param Model Model whose palette to draw (its layout cache updates).
   --  @param Region_X Left edge of the palette region in pixels.
   --  @param Region_Y Top edge of the palette region in pixels.
   --  @param Region_Width Palette region width in pixels.
   --  @param Region_Height Palette region height in pixels.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Line_Height Row height in pixels.
   --  @param Focused Whether the search box has keyboard focus.
   --  @param Rectangles Out: rectangle commands.
   --  @param Text Out: text commands.
   --  @param Icons Out: icon commands.
   --  @param Accessibility Out: accessibility nodes.
   procedure Build_Palette_Frame
     (Model         : in out Files.Model.Window_Model;
      Region_X      : Natural;
      Region_Y      : Natural;
      Region_Width  : Natural;
      Region_Height : Natural;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Line_Height   : Positive;
      Focused       : Boolean;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Icons         : out Guikit.Draw.Icon_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector);

   --  Draw the settings panel within a region, its fields rebuilt from the
   --  model's draft and its texts in the current language.
   --
   --  @param Model Model whose panel to draw (its layout cache updates).
   --  @param Region_X Left edge of the panel region in pixels.
   --  @param Region_Y Top edge of the panel region in pixels.
   --  @param Region_Width Panel region width in pixels.
   --  @param Region_Height Panel region height in pixels.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Line_Height Row height in pixels.
   --  @param Focused Whether the panel has keyboard focus.
   --  @param Hover_X Cursor X in pixels, or negative when off-window (drives the
   --    tab-switcher hover tooltip).
   --  @param Hover_Y Cursor Y in pixels.
   --  @param Rectangles Out: rectangle commands.
   --  @param Text Out: text commands.
   --  @param Accessibility Out: accessibility nodes.
   procedure Build_Settings_Frame
     (Model         : in out Files.Model.Window_Model;
      Region_X      : Natural;
      Region_Y      : Natural;
      Region_Width  : Natural;
      Region_Height : Natural;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Line_Height   : Positive;
      Focused       : Boolean;
      Hover_X       : Integer := -1;
      Hover_Y       : Integer := -1;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector);

end Files.Overlays;
