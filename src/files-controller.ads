with Files.Commands;
with Files.Events;
with Files.File_System;
with Files.Model;
with Files.Operations;
with Files.Settings;
with Files.Types;

--  Focus-aware input controller for command, text, palette, and filesystem operations.
package Files.Controller is

   type Controller_Status is
     (Controller_Ignored,
      Controller_Command_Executed,
      Controller_Selection_Moved,
      Controller_Text_Updated,
      Controller_Palette_Updated);

   type Controller_Result is record
      Status    : Controller_Status := Controller_Ignored;
      Command   : Files.Commands.Command_Id := Files.Commands.No_Command;
      Operation : Files.Operations.Operation_Result;
   end record;

   --  Replace the text of the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @param Text New text for the focused input.
   procedure Replace_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String);

   --  Append text to the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @param Text Text to append to the focused input.
   --  @return Controller result indicating whether text changed.
   function Append_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String)
      return Controller_Result;

   --  Remove the final character from the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @return Controller result indicating whether text changed.
   function Delete_Focused_Text_Backward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result;

   --  Remove the character at the cursor from the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @return Controller result indicating whether text changed.
   function Delete_Focused_Text_Forward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result;

   --  Remove the previous word from the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @return Controller result indicating whether text changed.
   function Delete_Focused_Text_Word_Backward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result;

   --  Remove the next word from the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @return Controller result indicating whether text changed.
   function Delete_Focused_Text_Word_Forward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result;

   --  Execute a command through the controller's filesystem-aware routing.
   --
   --  @param Id Command identifier.
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Modifiers Active modifier keys.
   --  @return Controller result with any operation details.
   function Execute_Command
     (Id        : Files.Commands.Command_Id;
      Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
      return Controller_Result;

   --  Validate, save, apply, and refresh edited settings.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model to replace on success.
   --  @param Settings_Path Central settings file path.
   --  @return Controller result with persistence operation details.
   function Save_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result;

   --  Import the central settings file into the editable draft.
   --
   --  @param Model Window model to update.
   --  @param Settings_Path Central settings file path.
   --  @return Controller result with import operation details.
   function Import_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings_Path : String)
      return Controller_Result;

   --  Export the current applied settings to the central settings file.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model to export.
   --  @param Settings_Path Central settings file path.
   --  @return Controller result with export operation details.
   function Export_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result;

   --  Execute a command produced by a toolbar or bottom-bar hit test.
   --
   --  @param Id Command identifier from the clicked UI control.
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Modifiers Active modifier keys.
   --  @return Controller result with command or operation details.
   function Handle_Command_Click
     (Id        : Files.Commands.Command_Id;
      Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
      return Controller_Result;

   --  Select a root path from the root selector.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Root_Path Root path selected by the user.
   --  @return Controller result with navigation details.
   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Controller_Result;

   --  Select a root-selector row by index.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Root_Index One-based root selector index, or zero for no row.
   --  @return Controller result with navigation details.
   function Handle_Root_Click
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Root_Index : Natural)
      return Controller_Result;

   --  Execute a command-palette result by index.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Result_Index One-based command-palette result index, or zero for no row.
   --  @param Modifiers Active modifier keys for open actions.
   --  @return Controller result with command or operation details.
   function Handle_Command_Result_Click
     (Model        : in out Files.Model.Window_Model;
      Settings     : Files.Settings.Settings_Model;
      Result_Index : Natural;
      Modifiers    : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
      return Controller_Result;

   --  Select or activate a visible item.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Visible_Index One-based visible item index, or zero for no item.
   --  @param Activate True to open the item after selecting it.
   --  @param Modifiers Active modifier keys for open actions.
   --  @return Controller result with selection or open details.
   function Handle_Item_Click
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Visible_Index : Natural;
      Activate      : Boolean := False;
      Modifiers     : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
      return Controller_Result;

   --  Import paths dropped into the current window.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Source_Paths Dropped filesystem paths.
   --  @param Mode Copy or move mode.
   --  @return Controller result with drop-import operation details.
   function Handle_Drop_Import
     (Model        : in out Files.Model.Window_Model;
      Settings     : Files.Settings.Settings_Model;
      Source_Paths : Files.Types.String_Vectors.Vector;
      Mode         : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy)
      return Controller_Result;

   --  Handle a scroll-wheel action for overlays that accept vertical movement.
   --
   --  @param Model Window model to update.
   --  @param Lines Positive values scroll down; negative values scroll up.
   --  @return Controller result describing whether visible state changed.
   function Handle_Scroll
     (Model : in out Files.Model.Window_Model;
      Lines : Integer)
      return Controller_Result;

   --  Handle a scroll action for a specific scrollable area.
   --
   --  @param Model Window model to update.
   --  @param Target Scrollable area that should consume the movement.
   --  @param Lines Positive values scroll down; negative values scroll up.
   --  @return Controller result describing whether visible state changed.
   function Handle_Targeted_Scroll
     (Model  : in out Files.Model.Window_Model;
      Target : Files.Events.Scroll_Target;
      Lines  : Integer)
      return Controller_Result;

   --  Focus a text field from a mouse click and place its cursor.
   --
   --  @param Model Window model to update.
   --  @param Target Text input target to focus.
   --  @param Cursor_Position Zero-based cursor position to set after focus.
   --  @return Controller result describing whether text focus changed.
   function Handle_Text_Click
     (Model           : in out Files.Model.Window_Model;
      Target          : Files.Types.Focus_Target;
      Cursor_Position : Natural)
      return Controller_Result;

   --  Handle a click inside the settings pane.
   --
   --  @param Model Window model to update.
   --  @param Field Settings field selected by the click.
   --  @param Option Optional clicked option or action code.
   --  @return Controller result describing whether settings state changed.
   function Handle_Settings_Click
     (Model  : in out Files.Model.Window_Model;
      Field  : Natural;
      Option : Natural := 0)
      return Controller_Result;

   --  Handle one key press using focus-aware command routing.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Key Key code.
   --  @param Modifiers Active modifier keys.
   --  @return Controller result with any operation details.
   function Handle_Key
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Key       : Files.Types.Key_Code;
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
      return Controller_Result;

end Files.Controller;
