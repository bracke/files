separate (Files_Suite.Operations)
   procedure Test_Toggle_Hidden_Files (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir           : constant String := Join (Root, "hidden-toggle");
      Settings_Path : constant String := Join (Root, "hidden-toggle-settings.txt");
      Settings      : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load          : Files.File_System.Directory_Load_Result;
      Model         : Files.Model.Window_Model;
      Result        : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Join (Dir, "visible.txt"));
      Write_File (Join (Dir, ".hidden"));

      Settings.Show_Hidden_Files := False;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Dir);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         1,
         "dotfile is hidden while show-hidden is disabled");

      Result := Files.Controller.Toggle_Hidden_Files (Model, Settings, Settings_Path);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "toggle hidden files reports success");
      Assert
        (Settings.Show_Hidden_Files,
         "toggle hidden files flips the live setting to enabled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         2,
         "reloaded model includes the previously hidden dotfile");
      Assert
        (Ada.Directories.Exists (Settings_Path),
         "toggle hidden files writes the settings file to disk");

      declare
         Reloaded : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Load_File (Settings_Path);
      begin
         Assert (Reloaded.Success, "persisted settings file parses successfully");
         Assert
           (Reloaded.Settings.Show_Hidden_Files,
            "persisted settings file records the enabled show-hidden flag");
      end;
   end Test_Toggle_Hidden_Files;
