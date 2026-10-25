separate (Files_Suite.Interaction)
   procedure Test_Extract_Enablement_By_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Zlib.Status_Code;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "extract-enable");
      Plain    : constant String := Files_Suite.Support.Join (Dir, "report.txt");
      Bundle   : constant String := Files_Suite.Support.Join (Dir, "bundle.zip");
      Inputs   : Zlib.Text_Array (1 .. 1);
      Names    : Zlib.Text_Array (1 .. 1);
      Status   : Zlib.Status_Code;
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Plain, "payload");
      Inputs (1) := Ada.Strings.Unbounded.To_Unbounded_String (Plain);
      Names (1) := Ada.Strings.Unbounded.To_Unbounded_String ("report.txt");
      Zlib.ZIP_Files (Inputs, Bundle, Names, Status => Status);
      Assert (Status = Zlib.Ok, "the test archive is created for the enablement check");

      --  A plain-file selection: Extract is listed but disabled.
      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (Menu_Offers (Model, Settings, Files.Commands.Extract_Archive_Command),
              "Extract is listed for a plain-file selection");
      Assert (not Files.Commands.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "Extract is disabled when the selection holds no archive");

      --  An archive selection: Extract is enabled.
      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "bundle.zip");
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (Files.Commands.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "Extract is enabled when the selection includes an archive");
   end Test_Extract_Enablement_By_Selection;
