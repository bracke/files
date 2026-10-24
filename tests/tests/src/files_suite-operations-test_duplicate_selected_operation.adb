separate (Files_Suite.Operations)
   procedure Test_Duplicate_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings   : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir        : constant String := Join (Root, "duplicate");
      Source     : constant String := Join (Dir, "report.txt");
      Copy_Path  : constant String := Join (Dir, "report (copy).txt");
      Payload    : constant String := "duplicate payload contents";
      Load       : Files.File_System.Directory_Load_Result;
      Model      : Files.Model.Window_Model;
      Routed     : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source, Payload);

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Duplicate_Selected_Command, Model),
         "duplicate command is enabled with a selection");

      Routed := Files.Controller.Execute_Command (Files.Commands.Duplicate_Selected_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "duplicate succeeds");
      Assert (Ada.Directories.Exists (Source), "original item still exists after duplicating");
      Assert (Ada.Directories.Exists (Copy_Path), "duplicate is created with a distinct name");
      Assert
        (Project_Tools.Files.Read_Raw_File (Copy_Path) = Project_Tools.Files.Read_Raw_File (Source),
         "duplicate has identical contents to the original");

      --  A dotfile has no extension: its copy is ".bashrc (copy)", not " (copy).bashrc".
      Write_File (Join (Dir, ".bashrc"), "rc");
      declare
         Hidden : Files.Settings.Settings_Model := Settings;
      begin
         Hidden.Show_Hidden_Files := True;
         Load := Files.File_System.Load_Directory (Dir, Hidden);
         Files.Model.Initialize (Model, Dir, Load.Items, Root);
         Select_Name (Model, ".bashrc");
         Routed := Files.Controller.Execute_Command (Files.Commands.Duplicate_Selected_Command, Model, Hidden);
         Assert (Ada.Directories.Exists (Join (Dir, ".bashrc (copy)"))
                   and then not Ada.Directories.Exists (Join (Dir, " (copy).bashrc")),
                 "a dotfile duplicate keeps the leading-dot name whole");
      end;
   end Test_Duplicate_Selected_Operation;
