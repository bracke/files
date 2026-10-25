separate (Files_Suite.Operations)
   procedure Test_Unreadable_Hardlink_History
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir : constant String := Join (Root, "unreadable-hardlink");
      Source : constant String := Join (Dir, "report.txt");
      Link_Path : constant String := Join (Dir, "report (link).txt");
      Load : Files.File_System.Directory_Load_Result;
      Model : Files.Model.Window_Model;
      Routed : Files.Controller.Controller_Result;
      Step : Files.Operations.Operation_Result;
   begin
      if not Hostkit.Metadata.Mode_Bits_Are_Native then
         Files_Suite.Support.Skip ("Test_Unreadable_Hardlink_History", "needs native POSIX mode bits");
         return;
      end if;

      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source, "hard link contents");
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");
      Routed := Files.Controller.Execute_Command
        (Files.Commands.Create_Hardlink_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "readable hard link is created");
      Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operations.Operation_Success,
         "hard link is removed before Redo");
      Assert (Files.File_System.Set_Permissions (Source, 0).Success,
              "source permissions can be removed");

      Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operations.Operation_Failed,
         "Redo refuses an unreadable hard link before publication");
      Assert (not Ada.Directories.Exists (Link_Path),
              "failed Redo leaves no hard link behind");
      Assert (Files.File_System.Set_Permissions (Source, 8#644#).Success,
              "source permissions can be restored");
      Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operations.Operation_Success,
         "Redo can retry after the source becomes readable");
      Assert (Ada.Directories.Exists (Link_Path), "retry publishes the hard link");

      Files.Operations.Clear_Undo (Model);
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source, "hard link contents");
      Assert (Files.File_System.Set_Permissions (Source, 0).Success,
              "new source permissions can be removed");
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");
      Routed := Files.Controller.Execute_Command
        (Files.Commands.Create_Hardlink_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "creating an unreadable hard link reports success");
      Assert (Ada.Directories.Exists (Link_Path),
              "unreadable hard link is actually published");
      Assert (not Files.Model.Undo_Available (Model),
              "unsafe deletion is not recorded as Undo");
      Assert (Files.File_System.Set_Permissions (Source, 8#644#).Success,
              "new source permissions can be restored");
   end Test_Unreadable_Hardlink_History;
