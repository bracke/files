with Files.Settings.Storage;
with Files.Settings.Path_References;
with Project_Tools.Files;
with Files_Suite.Support.Guards;
separate (Files_Suite.Settings)
   --  Two processes share one settings file. What the other one wrote since
   --  this one last read or wrote the file is kept by this one's save: each
   --  setting this one changed is its own, every other is the file's; lists
   --  merge entry by entry, so a favorite each one added is kept. A shortcut
   --  the other rebound is taken in and in force. A file changed into
   --  something that does not load is not written over.
   procedure Test_Save_Keeps_Another_Process_Change (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path     : constant String := Join (Root, "shared-settings.conf");
      Favorite : constant String := Join (Root, "starred");
      Own_Star : constant String := Join (Root, "own-star");
      Shortcuts : Files_Suite.Support.Guards.Shortcut_Guard;
      pragma Unreferenced (Shortcuts);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Mine     : Files.Settings.Settings_Model;
      Theirs   : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Written  : Files.Settings.Settings_Write_Result;
      Loaded   : Files.Settings.Settings_Parse_Result;
      Revision : Natural;
      use type Files.Commands.Shortcut;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Favorite);
      Ada.Directories.Create_Path (Own_Star);
      Files.Commands.Reset_Shortcut_Overrides;
      Written := Files.Settings.Storage.Save_Text (Path, Files.Settings.To_Text (Files.Settings.Default_Settings));
      Assert (Written.Success, "the shared file is written");
      Loaded := Files.Settings.Storage.Load_File (Path);
      Assert (Loaded.Success, "and this process loads it");
      Mine := Loaded.Settings;

      --  The other process stars a folder, rebinds Small Icons and writes
      --  the file.
      Files.Settings.Path_References.Add_Favorite (Theirs, Favorite);
      Theirs.Shortcut_Overrides.Append
        (Files.Settings.Shortcut_Override'
           (Command => To_Unbounded_String (Files.Commands.Identifier (Files.Commands.Select_Small_Icons_Command)),
            Combo   => To_Unbounded_String ("control+shift+7")));
      Write_File (Path, Files.Settings.To_Text (Theirs));

      --  This one turns hidden files on, stars another folder and saves.
      Mine.Show_Hidden_Files := True;
      Files.Settings.Path_References.Add_Favorite (Mine, Own_Star);
      Revision := Files.Model.Settings_Revision (Model);
      Files.Controller.Persist_Settings (Model, Mine, Path);
      Assert (Mine.Show_Hidden_Files, "this process's change is kept");
      Assert (Files.Settings.Path_References.Is_Favorite (Mine, Favorite),
              "and the other's favorite is taken in");
      Assert (Files.Settings.Path_References.Is_Favorite (Mine, Own_Star),
              "beside this one's own new favorite");
      Assert (Files.Commands.Shortcut_For (Files.Commands.Select_Small_Icons_Command)
              = Files.Commands.Parse_Shortcut ("control+shift+7"),
              "and the other's rebind is in force here");
      Assert (Files.Model.Settings_Revision (Model) /= Revision, "which the window notes as a settings change");
      Loaded := Files.Settings.Storage.Load_File (Path);
      Assert (Loaded.Success and then Loaded.Settings.Show_Hidden_Files
              and then Files.Settings.Path_References.Is_Favorite (Loaded.Settings, Favorite)
              and then Files.Settings.Path_References.Is_Favorite (Loaded.Settings, Own_Star),
              "the file holds both");

      --  A file the other changed into something that does not load stays.
      Write_File (Path, "[settings]" & ASCII.LF & "show_hidden_files = maybe");
      declare
         --  As the other wrote it (Write_File's line ends are the host's).
         Unloadable : constant String := Project_Tools.Files.Read_Raw_File (Path);
      begin
         Mine.Show_Hidden_Files := False;
         Files.Controller.Persist_Settings (Model, Mine, Path);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model), "error.settings.changed_elsewhere",
            "a save over it is refused and said");
         Files_Suite.Support.Assert_Equal
           (Project_Tools.Files.Read_Raw_File (Path), Unloadable, "and the file is left as the other wrote it");
      end;
   end Test_Save_Keeps_Another_Process_Change;
