--  The command palette overlay: opening and closing it, its query and selection, the
--  Open With listing it can show instead of the commands, and the visit
--  through which the window layer drives its guikit component.
package Files.Model.Command_Palette is

   --  Open the command palette.
   --
   --  @param Model Model to update.
   procedure Open
     (Model : in out Window_Model);

   --  Close the command palette.
   --
   --  @param Model Model to update.
   procedure Close
     (Model : in out Window_Model);

   --  Toggle the command palette.
   --
   --  @param Model Model to update.
   procedure Toggle
     (Model : in out Window_Model);

   --  Return whether the command palette is open.
   --
   --  @param Model Model to inspect.
   --  @return True when command palette is open.
   function Is_Open
     (Model : Window_Model)
      return Boolean;

   --  The palette's current query text. Guikit.Command_Palette owns the query,
   --  selection and scroll; these only forward to it.
   --
   --  @param Model Model to inspect.
   --  @return The current query text.
   function Query (Model : Window_Model) return String;

   --  Replace the palette's query text (resets its selection).
   --
   --  @param Model Model to update.
   --  @param Text New query text.
   procedure Set_Query (Model : in out Window_Model; Text : String);

   --  Move the highlighted result by Delta_Rows (clamped/wrapped by the palette).
   --
   --  @param Model Model to update.
   --  @param Delta_Rows Signed number of rows to move the selection.
   procedure Move_Selection (Model : in out Window_Model; Delta_Rows : Integer);

   --  Highlight the first result.
   --
   --  @param Model Model to update.
   procedure Select_First (Model : in out Window_Model);

   --  Highlight the last result.
   --
   --  @param Model Model to update.
   procedure Select_Last (Model : in out Window_Model);

   --  Move the selection by one page.
   --
   --  @param Model Model to update.
   --  @param Down True to page down, False to page up.
   procedure Page (Model : in out Window_Model; Down : Boolean);

   --  Select the palette result at a window coordinate, using the last render.
   --
   --  @param Model Model to update.
   --  @param X Pointer x coordinate in pixels.
   --  @param Y Pointer y coordinate in pixels.
   --  @return True when a result row was hit (and is now selected).
   function Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean;

   --  The Id of the highlighted command, or 0 when none. In Palette_Commands
   --  mode this is Files.Commands.Command_Id'Pos of the command; in
   --  Palette_Open_With mode the one-based application index.
   --
   --  @param Model Model to inspect.
   --  @return The chosen command Id, or 0.
   function Selected_Id (Model : Window_Model) return Natural;

   --  Number of results matching the current query (from the last render's
   --  command list).
   --
   --  @param Model Model to inspect.
   --  @return The result count.
   function Result_Count (Model : Window_Model) return Natural;

   --  Return the active command-palette mode.
   --
   --  @param Model Model to inspect.
   --  @return Palette_Commands for the registered-command picker, or
   --  Palette_Open_With for the "Open With" application picker.
   function Mode_Of
     (Model : Window_Model)
      return Palette_Mode;

   --  Set the active command-palette mode.
   --
   --  @param Model Model to update.
   --  @param Mode New palette mode.
   procedure Set_Mode
     (Model : in out Window_Model;
      Mode  : Palette_Mode);

   --  Replace the stored "Open With" target paths.
   --
   --  @param Model Model to update.
   --  @param Targets Full paths the chosen application should open.
   procedure Set_Open_With_Targets
     (Model   : in out Window_Model;
      Targets : Files.Types.String_Vectors.Vector);

   --  Return the stored "Open With" target paths.
   --
   --  @param Model Model to inspect.
   --  @return Full paths captured for the "Open With" picker.
   function Open_With_Targets
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Store the applications the "Open With" picker lists. The caller scans
   --  once when the picker opens; the list drawn and the one a choice is
   --  resolved against are then the same, however the installed set changes.
   --
   --  @param Model Model to update.
   --  @param Applications Installed applications, in picker order.
   procedure Set_Open_With_Applications
     (Model        : in out Window_Model;
      Applications : Files.Desktop_Applications.Application_Vectors.Vector);

   --  Return the applications the "Open With" picker lists.
   --
   --  @param Model Model to inspect.
   --  @return The list stored when the picker opened; empty otherwise. A
   --    picker Id is a one-based index into it.
   function Open_With_Applications
     (Model : Window_Model)
      return Files.Desktop_Applications.Application_Vectors.Vector;

   --  Focus the command-palette input without changing its existing query.
   --
   --  @param Model Model to update.
   procedure Focus_Input
     (Model : in out Window_Model);

   --  Refresh the command palette for this frame -- its line height, and its
   --  command list (their enablement) after a model change -- and hand it to
   --  Draw, which draws it: the model holds the palette's state (query,
   --  selection, scroll), the window layer renders.
   --
   --  @param Model Model whose palette to visit.
   --  @param Line_Height Row height in pixels.
   --  @param Title The palette's heading, in the current language.
   --  @param Empty_State What it shows when no command matches.
   --  @param Close_Label Its close button's accessible name, in the current
   --    language.
   --  @param Draw Draws the palette.
   procedure Visit
     (Model       : in out Window_Model;
      Line_Height : Positive;
      Title       : String;
      Empty_State : String;
      Close_Label : String;
      Draw        : not null access procedure (Palette : in out Guikit.Command_Palette.Palette));

end Files.Model.Command_Palette;
