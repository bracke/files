with Guikit.Draw;

with Files.Model;

--  Drawing the window's stateful overlays -- the command palette and the
--  settings panel -- from the state the model holds for them. The window
--  layer merges what this draws over the cached frame (Append_Overlay); the
--  model itself draws nothing and localizes nothing for them.
package Files.Overlays is

   --  Where an overlay is drawn: its region, the window it is clipped to,
   --  and the row height.
   type Overlay_Region is record
      X           : Natural := 0;
      Y           : Natural := 0;
      Width       : Natural := 0;
      Height      : Natural := 0;
      Clip_Width  : Natural := 0;
      Clip_Height : Natural := 0;
      Line_Height : Positive := 1;
   end record;

   --  Draw the command palette within a region.
   --
   --  @param Model Model whose palette to draw (its layout cache updates).
   --  @param Region Where the overlay is drawn, and the window it is clipped to.
   --  @param Focused Whether the search box has keyboard focus.
   --  @param Rectangles Out: rectangle commands.
   --  @param Text Out: text commands.
   --  @param Icons Out: icon commands.
   --  @param Accessibility Out: accessibility nodes.
   procedure Build_Palette_Frame
     (Model         : in out Files.Model.Window_Model;
      Region        : Overlay_Region;
      Focused       : Boolean;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Icons         : out Guikit.Draw.Icon_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector);

   --  Draw the settings panel within a region, its fields rebuilt from the
   --  model's draft and its texts in the current language.
   --
   --  @param Model Model whose panel to draw (its layout cache updates).
   --  @param Region Where the overlay is drawn, and the window it is clipped to.
   --  @param Focused Whether the panel has keyboard focus.
   --  @param Hover_X Cursor X in pixels, or negative when off-window (drives the
   --    tab-switcher hover tooltip).
   --  @param Hover_Y Cursor Y in pixels.
   --  @param Rectangles Out: rectangle commands.
   --  @param Text Out: text commands.
   --  @param Accessibility Out: accessibility nodes.
   procedure Build_Settings_Frame
     (Model         : in out Files.Model.Window_Model;
      Region        : Overlay_Region;
      Focused       : Boolean;
      Hover_X       : Integer := -1;
      Hover_Y       : Integer := -1;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector);

end Files.Overlays;
