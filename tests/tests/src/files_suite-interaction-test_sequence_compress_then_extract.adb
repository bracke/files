separate (Files_Suite.Interaction)
   procedure Test_Sequence_Compress_Then_Extract (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "compress-seq");
      Source   : constant String := Files_Suite.Support.Join (Dir, "report.txt");
      Zip_Path : constant String := Files_Suite.Support.Join (Dir, "report.zip");
      Dest     : constant String := Files_Suite.Support.Join (Dir, "report");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Source, "payload");

      --  Step 1: compress the file to a zip via the item menu.
      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Compress_Zip_Command, Result, Found);
      Assert (Found, "the item menu offers the compress-zip command");
      Assert (Ada.Directories.Exists (Zip_Path), "compress-zip writes the archive");

      --  Step 2: reload so the new archive appears, select it, and extract.
      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.zip");
      Assert (Files.Model.Selected_Count (Model) > 0, "the reloaded listing contains the new archive");
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (Files.Commands.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "Extract is enabled on the reloaded archive selection");
      Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Extract_Archive_Command, Result, Found);
      Assert (Found, "the item menu offers the extract command");
      Assert (Ada.Directories.Exists (Dest), "extract creates a folder from the archive base name");
      Assert
        (Ada.Directories.Exists (Files_Suite.Support.Join (Dest, "report.txt")),
         "extract writes the archived entry into the new folder");
   end Test_Sequence_Compress_Then_Extract;
