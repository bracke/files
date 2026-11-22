with Files.Commands.Status;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Models;
separate (Files_Suite.Context_Menu)
   procedure Test_Extract_Enablement_By_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Zlib.Status_Code;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Dir      : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "extract-enable");
      Plain    : constant String := Files_Suite.Support.Disk.Join (Dir, "report.txt");
      Bundle   : constant String := Files_Suite.Support.Disk.Join (Dir, "bundle.zip");
      Inputs   : Zlib.Text_Array (1 .. 1);
      Names    : Zlib.Text_Array (1 .. 1);
      Status   : Zlib.Status_Code;
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Disk.Write_File (Plain, "payload");
      Inputs (1) := Ada.Strings.Unbounded.To_Unbounded_String (Plain);
      Names (1) := Ada.Strings.Unbounded.To_Unbounded_String ("report.txt");
      Zlib.ZIP_Files (Inputs, Bundle, Names, Status => Status);
      Assert (Status = Zlib.Ok, "the test archive is created for the enablement check");

      --  A plain-file selection: Extract is listed but disabled.
      Model := Loaded_Model (Dir);
      Files_Suite.Support.Models.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (Menu_Offers (Model, Settings, Files.Commands.Extract_Archive_Command),
              "Extract is listed for a plain-file selection");
      Assert (not Files.Commands.Status.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "Extract is disabled when the selection holds no archive");

      --  An archive selection: Extract is enabled.
      Model := Loaded_Model (Dir);
      Files_Suite.Support.Models.Select_Name (Model, "bundle.zip");
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "Extract is enabled when the selection includes an archive");

      --  The answer is kept with the selection it was worked out for: a
      --  new selection in the same window asks again.
      Files_Suite.Support.Models.Select_Name (Model, "report.txt");
      Assert (not Files.Commands.Status.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "Extract is disabled again once the plain file alone is selected");
      Files_Suite.Support.Models.Select_Name (Model, "bundle.zip");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "and enabled again for the archive");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "asked twice, the kept answer stands");
   end Test_Extract_Enablement_By_Selection;
