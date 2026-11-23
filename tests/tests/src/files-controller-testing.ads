--  Test-only access to private subprograms of Files.Controller, kept out of the program.
package Files.Controller.Testing is

   --  Replace the text of the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @param Text New text for the focused input.
   procedure Replace_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String);

   --  Fold the queued opened items and path moves into the settings as one
   --  edit (Files.Controller.Note_Recent_Opens).
   --
   --  @param Model Model whose queues are drained.
   --  @param Settings Live settings model.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Accepted True when a change took.
   procedure Note_Recent_Opens
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Accepted      : out Boolean);

   --  The one policy for a settings change (Files.Controller.Commit_Settings):
   --  Updated replaces Settings and is saved, unless the file could not hold
   --  it -- then it is refused whole and the error line says so.
   --
   --  @param Model Window whose error line reports a refused change or a failed write.
   --  @param Settings Live settings model, replaced by Updated when it is accepted.
   --  @param Updated The settings with the change made.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @return The write's result; Success is False for a refused change.
   function Commit_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Updated       : Files.Settings.Settings_Model;
      Settings_Path : String)
      return Files.Settings.Settings_Write_Result;

   --  Validate, apply, refresh, and save edited settings (Commit_Settings): a
   --  valid draft is applied even when the save then fails, and the failure
   --  is reported; one the file could not hold is refused. An unchanged draft
   --  is written again, so Save retries a save that failed.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model, replaced when the draft is valid.
   --  @param Settings_Path Central settings file path.
   --  @return Controller result with persistence operation details.
   function Save_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result;

   --  Toggle hidden-file visibility, persist it, and reload the directory.
   --
   --  Flips Settings.Show_Hidden_Files, refreshes the current directory so it
   --  reloads with the new visibility, and writes the settings file. Like every
   --  settings change, a save failure keeps the change for the session: the
   --  model error is set and the result's operation reports the failure.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model whose visibility flag is flipped.
   --  @param Settings_Path Central settings file path.
   --  @return Controller result with persistence operation details.
   function Toggle_Hidden_Files
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result;

   --  Cycle the status bar's disk-space field through free space, used space
   --  and a bar (Show_Used_Space, Show_Space_Bar) and persist it. Display
   --  only: the item list is unchanged and the directory is not reloaded.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model whose space-display flags change.
   --  @param Settings_Path Central settings file path.
   --  @return Controller result with persistence operation details.
   function Toggle_Free_Space_Display
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result;

   --  Handle_Key for a key as the window delivers it: translated as
   --  Files.Interaction.Handle_Key translates it, then handled.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Key Key code.
   --  @param Modifiers Active modifier keys.
   --  @param Tree_Page_Rows Folder-tree rows visible in the live viewport, or
   --    zero when geometry is unavailable.
   --  @return Controller result with any operation details.
   function Handle_Key
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Tree_Page_Rows : Natural := 0)
      return Controller_Result;

   --  Import paths dropped into the current window through the paste engine, so
   --  a drop gets the same conflict dialog and resumable progress/cancel overlay
   --  as clipboard paste (a name collision arms the dialog instead of silently
   --  auto-renaming).
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
      Mode         : Files.File_System_Types.Drop_Import_Mode := Files.File_System_Types.Drop_Copy)
      return Controller_Result;

   --  Whether dropped paths may be imported now: not while an overlay owns
   --  the input (a dialog, the palette, a paste's progress), which would turn
   --  the import away. Until it closes the drop stays queued, not lost.
   --
   --  @param Model Window model to inspect.
   --  @return True when Handle_Drop_Import would import a drop.
   function Accepts_Drop_Import (Model : Files.Model.Window_Model) return Boolean;

   --  Act on the command palette's highlighted command, as Enter and a click
   --  on its row do.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model used by operations.
   --  @param Modifiers Active modifier keys for open actions.
   --  @return Controller result with command or operation details.
   function Activate_Palette_Command
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result;

end Files.Controller.Testing;
