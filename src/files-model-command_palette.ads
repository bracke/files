with Files.Commands;
with Files.Desktop_Applications;
with Guikit.Command_Palette;
--  The command palette overlay: opening and closing it, its query and selection, the
--  Open With listing it can show instead of the commands, the command list
--  its guikit component holds (built, in the current language, outside the
--  model by Files.Overlays.Command_Palette, which hands it over through List) and the
--  command a chosen row names, and the visit through which the window layer
--  drives that component.
--  Guikit.Command_Palette owns the query, selection, scroll, filtering and
--  rendering.
package Files.Model.Command_Palette is

   --  Whether the palette holds the command list for the model as it is: one
   --  was handed over (List) since the model last changed. Opening the
   --  palette, and any change after, leaves it unlisted until then.
   --
   --  @param Model Model to inspect.
   --  @return True when the listed commands are current.
   function Is_Listed
     (Model : Window_Model)
      return Boolean;

   --  Hand the palette the commands it lists, in the current mode, unfiltered
   --  (Files.Overlays.Command_Palette.Commands): the query and the selection are kept,
   --  the selection clamped to the new results.
   --
   --  @param Model Model whose palette lists them; Is_Listed is True after.
   --  @param Commands Every visible registered command (Commands mode), each
   --    Id its Files.Commands enumeration position, or every listed
   --    application (Open-With mode), each Id its one-based index into
   --    Open_With_Applications.
   procedure List
     (Model    : in out Window_Model;
      Commands : Guikit.Command_Palette.Command_Vectors.Vector);

   --  The command of the palette's highlighted row: the inverse of the Id
   --  List gives each row in Commands mode. No_Command in Open-With mode,
   --  with nothing highlighted, or for an Id outside the enumeration (a stale
   --  or malformed palette model).
   --
   --  @param Model Current model, for the mode and the highlighted row.
   --  @return The highlighted command, or No_Command.
   function Selected_Command
     (Model : Window_Model)
      return Files.Commands.Command_Id;

   --  Leave the palette unlisted (Is_Listed), so it is listed again before
   --  its next use: what a row shows beyond this model -- a shortcut, which
   --  another window may have rebound -- changed.
   --
   --  @param Model Model whose palette is listed again.
   procedure Relist
     (Model : in out Window_Model);

   --  Open the command palette, with nothing listed yet (Is_Listed is
   --  False) until List hands it its commands.
   --
   --  @param Model Model to update.
   procedure Open
     (Model : in out Window_Model);

   --  Open the command palette as the "Open With" picker: Applications are
   --  listed (once List hands them over) for the user to choose the one that
   --  opens Targets. The list is stored once, here, so the list drawn and the
   --  one a choice is resolved against are the same however the installed
   --  set changes.
   --
   --  @param Model Model to update.
   --  @param Targets Full paths the chosen application should open.
   --  @param Applications Installed applications, in picker order.
   procedure Open_With
     (Model        : in out Window_Model;
      Targets      : Files.Types.String_Vectors.Vector;
      Applications : Files.Desktop_Applications.Application_Vectors.Vector);

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

   --  Return the stored "Open With" target paths.
   --
   --  @param Model Model to inspect.
   --  @return Full paths captured for the "Open With" picker.
   function Open_With_Targets
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

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

   --  Refresh the command palette for this frame -- its line height and
   --  texts -- and hand it to Draw, which draws it: the model holds the
   --  palette's state (query, selection, scroll, the commands listed), the
   --  window layer lists (List) and renders.
   --
   --  @param Model Model whose palette to visit.
   --  @param Line_Height Row height in pixels.
   --  @param Title The palette's heading, in the current language.
   --  @param Empty_State What it shows when no command matches.
   --  @param Close_Label Its close button's accessible name, in the current
   --    language.
   --  @param Draw Draws the palette.
   procedure With_Panel
     (Model       : in out Window_Model;
      Line_Height : Positive;
      Title       : String;
      Empty_State : String;
      Close_Label : String;
      Draw        : not null access procedure (Palette : in out Guikit.Command_Palette.Palette));

end Files.Model.Command_Palette;
