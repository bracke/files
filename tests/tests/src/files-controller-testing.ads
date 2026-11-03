--  Test-only access to private subprograms of Files.Controller, kept out of the program.
package Files.Controller.Testing is

   --  Replace the text of the currently focused text input.
   --
   --  @param Model Window model to update.
   --  @param Text New text for the focused input.
   procedure Replace_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String);

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

   --  Flip the Show_Used_Space setting and persist it, so the status bar's
   --  disk-space field switches between showing free and used space. Display
   --  only: the item list is unchanged and the directory is not reloaded.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model whose free/used flag is flipped.
   --  @param Settings_Path Central settings file path.
   --  @return Controller result with persistence operation details.
   function Toggle_Free_Space_Display
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
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

end Files.Controller.Testing;
