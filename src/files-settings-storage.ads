--  Writing the settings file, and the policy every settings change is saved
--  by, below the window layer: the live keymap is written with the
--  settings (Files.Commands.Keymap_Settings), what another process wrote
--  since is taken in first (Merge_From_File), and settings that would not
--  load again are never written. Files.Controller applies the outcome to a
--  window (its error line, taking merged-in settings into the open pane
--  and listing).
package Files.Settings.Storage is

   --  The result of a settings write refused because the settings would be
   --  too big to load again.
   --
   --  @param Settings_Path Central settings file path.
   --  @return A failed, not durable result naming error.settings.full.
   function Full_Result (Settings_Path : String) return Settings_Write_Result;

   --  The result of a change that said nothing new: saved, as it was.
   --
   --  @param Settings_Path Central settings file path.
   --  @return A successful, durable result.
   function Unchanged_Result (Settings_Path : String) return Settings_Write_Result;

   --  The one place settings are written. An empty path turns persistence
   --  off (smoke runs, tests): the settings apply in memory and count as
   --  saved. A session whose settings file could not be loaded refuses to
   --  write it: the change applies in memory and the result says it was not
   --  saved. The shortcut overrides written are the live keymap's, a rebind
   --  not saved yet included. What another process wrote to the file since
   --  this one saw it is taken into Settings first (Merge_From_File), its
   --  shortcuts made the live keymap and held as a save writes them; a file
   --  changed into one this build cannot load is not written over, nor is a
   --  merge that would make it too big to load (Settings then stay as they
   --  were).
   --
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Settings Settings to write; takes in another process's changes.
   --  @return The write's result.
   function Write
     (Settings_Path : String;
      Settings      : in out Settings_Model)
      return Settings_Write_Result;

   --  Save already-applied settings: settings that would not load again are
   --  not written (Full_Result); otherwise Write.
   --
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Settings Settings to write; takes in another process's changes.
   --  @param Taken_In True when the save changed Settings (another process's
   --    change, or a rebind not saved before, taken in): the caller makes
   --    them in force in its window.
   --  @return The write's result.
   function Persist
     (Settings_Path : String;
      Settings      : in out Settings_Model;
      Taken_In      : out Boolean)
      return Settings_Write_Result;

   --  What a settings change comes to before it is applied.
   --  Commit_Unchanged: Updated says nothing new and nothing is written.
   --  Commit_Refused: Updated would make loadable settings unloadable; the
   --  change is refused whole. Commit_Accepted: Updated replaces the
   --  settings and is saved (Persist).
   type Commit_Decision is (Commit_Unchanged, Commit_Refused, Commit_Accepted);

   --  Decide a settings change. Settings that already would not load take a
   --  change (refusing every later change, a zoom or a toggle, would only
   --  lock the user out); Persist then still writes nothing.
   --
   --  @param Current The live settings.
   --  @param Updated The settings with the change made.
   --  @return What becomes of the change.
   function Decide_Commit
     (Current : Settings_Model;
      Updated : Settings_Model)
      return Commit_Decision;

end Files.Settings.Storage;
