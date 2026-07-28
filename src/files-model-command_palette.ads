--  The command palette state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Command_Palette is

   --  Focus the command-palette input without changing its existing query.
   --
   --  @param Model Model to update.
   procedure Focus_Command_Palette_Input
     (Model : in out Window_Model);

   --  Open the command palette.
   --
   --  @param Model Model to update.
   procedure Open_Command_Palette
     (Model : in out Window_Model);

   --  Close the command palette.
   --
   --  @param Model Model to update.
   procedure Close_Command_Palette
     (Model : in out Window_Model);

   --  Toggle the command palette.
   --
   --  @param Model Model to update.
   procedure Toggle_Command_Palette
     (Model : in out Window_Model);

   --  Return whether the command palette is open.
   --
   --  @param Model Model to inspect.
   --  @return True when command palette is open.
   function Command_Palette_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  The palette's current query text. Guikit.Command_Palette owns the query,
   --  selection and scroll; these only forward to it.
   --
   --  @param Model Model to inspect.
   --  @return The current query text.
   function Palette_Query (Model : Window_Model) return String;

   --  Replace the palette's query text (resets its selection).
   --
   --  @param Model Model to update.
   --  @param Text New query text.
   procedure Palette_Set_Query (Model : in out Window_Model; Text : String);

   --  Move the highlighted result by Delta_Rows (clamped/wrapped by the palette).
   --
   --  @param Model Model to update.
   --  @param Delta_Rows Signed number of rows to move the selection.
   procedure Palette_Move_Selection (Model : in out Window_Model; Delta_Rows : Integer);

   --  Highlight the first result.
   --
   --  @param Model Model to update.
   procedure Palette_Select_First (Model : in out Window_Model);

   --  Highlight the last result.
   --
   --  @param Model Model to update.
   procedure Palette_Select_Last (Model : in out Window_Model);

   --  Move the selection by one page.
   --
   --  @param Model Model to update.
   --  @param Down True to page down, False to page up.
   procedure Palette_Page (Model : in out Window_Model; Down : Boolean);

   --  Select the palette result at a window coordinate, using the last render.
   --
   --  @param Model Model to update.
   --  @param X Pointer x coordinate in pixels.
   --  @param Y Pointer y coordinate in pixels.
   --  @return True when a result row was hit (and is now selected).
   function Palette_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean;

   --  The Id of the highlighted command, or 0 when none. In Palette_Commands
   --  mode this is Files.Commands.Command_Id'Pos of the command; in
   --  Palette_Open_With mode the one-based application index.
   --
   --  @param Model Model to inspect.
   --  @return The chosen command Id, or 0.
   function Palette_Selected_Id (Model : Window_Model) return Natural;

   --  Number of results matching the current query (from the last render's
   --  command list).
   --
   --  @param Model Model to inspect.
   --  @return The result count.
   function Palette_Result_Count (Model : Window_Model) return Natural;

   --  Render the command palette within a region, refreshing its command list
   --  (fresh enablement) and line height first. Emits draw commands and
   --  accessibility nodes for the caller to submit.
   --
   --  @param Model Model to render from (updates the palette's cached layout).
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
   procedure Palette_Build_Frame
     (Model         : in out Window_Model;
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

   --  Return the active command-palette mode.
   --
   --  @param Model Model to inspect.
   --  @return Palette_Commands for the registered-command picker, or
   --  Palette_Open_With for the "Open With" application picker.
   function Command_Palette_Mode_Of
     (Model : Window_Model)
      return Palette_Mode;

   --  Set the active command-palette mode.
   --
   --  @param Model Model to update.
   --  @param Mode New palette mode.
   procedure Set_Command_Palette_Mode
     (Model : in out Window_Model;
      Mode  : Palette_Mode);

end Files.Model.Command_Palette;
