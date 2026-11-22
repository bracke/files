--  Reading and writing the settings file (Load_File, Save_Text,
--  Merge_From_File, Ensure_Default_File), and the policy every settings
--  change is saved by, below the window layer: what another process wrote
--  since is taken in first (Merge_From_File), and settings that would not
--  load again are never written. It writes exactly the settings it is
--  handed: Files.Controller stores the live keymap into them first
--  (Files.Commands.Keymap_Settings), puts a rebind taken in from the file
--  in force, and applies the outcome to a window (its error line, taking
--  merged-in settings into the open pane and listing).
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
   --  saved. The shortcut overrides written are Settings' own (the caller
   --  stores the live keymap into them). What another process wrote to the
   --  file since this one saw it is taken into Settings first
   --  (Merge_From_File), its shortcuts included, for the caller to put in
   --  force; a file
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

   --  Load settings from a filesystem path.
   --
   --  Missing files return default settings successfully. Existing invalid files
   --  return a failed parse result with a diagnostic key.
   --
   --  @param Path Settings file path.
   --  @return Loaded settings or a deterministic diagnostic key.
   function Load_File
     (Path : String)
      return Settings_Parse_Result;

   --  Write default settings to Path when it does not already exist.
   --
   --  Parent directories are created as needed. Existing regular files are left
   --  unchanged. Existing non-regular paths are reported as not-file errors.
   --
   --  @param Path Settings file path to ensure.
   --  @return Write result with path and deterministic diagnostic key.
   function Ensure_Default_File
     (Path : String)
      return Settings_Write_Result;

   --  Restate what the settings file at Path, as this process last read or
   --  wrote it, says: Settings, when this process holds them in another form
   --  than the file spells them (shortcut overrides held as a save writes
   --  them), so Merge_From_File does not take that form for a change of its
   --  own. Nothing happens for another path.
   --
   --  @param Path Settings file path.
   --  @param Settings What the file as last seen says.
   procedure Note_Seen_Settings (Path : String; Settings : Settings_Model);

   --  Take into Settings what another process (another files, an editor)
   --  wrote to the settings file at Path since this one last read or wrote
   --  it (Load_File, Save_Text), so a save does not throw that away. Each
   --  scalar keeps Settings' value where this process changed it since and
   --  takes the file's otherwise; the lists and mappings merge entry by
   --  entry: what this process added, removed or changed since is applied
   --  to the file's (favorites and labels in the file's order, this
   --  process's additions after; recent items this process opened since
   --  first, then the file's, capped). Nothing is taken when the file is as
   --  it was seen, cannot be read, or was never seen at Path; the file
   --  counts as seen only once it is written (Save_Text), so a merge that
   --  is not written is made again.
   --
   --  @param Path Settings file path about to be written.
   --  @param Settings This process's settings, merged in place.
   --  @param Merged Set when Settings took something from the file.
   --  @param Refused Set when the file was changed into something this
   --    build cannot load: writing over it would lose that change, so the
   --    caller does not write.
   procedure Merge_From_File
     (Path     : String;
      Settings : in out Settings_Model;
      Merged   : out Boolean;
      Refused  : out Boolean);

   --  Write settings text to Path, creating parent directories as needed.
   --
   --  @param Path Settings file path.
   --  @param Text Settings text to write.
   --  @return Write result with path and deterministic diagnostic key.
   function Save_Text
     (Path : String;
      Text : String)
      return Settings_Write_Result;

end Files.Settings.Storage;
