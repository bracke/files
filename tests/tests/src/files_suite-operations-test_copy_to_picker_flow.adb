separate (Files_Suite.Operations)
   procedure Test_Copy_To_Picker_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "copyto-src");
      Dest_Dir : constant String := Join (Root, "copyto-dest");
      A_Src    : constant String := Join (Src_Dir, "a.txt");
      B_Src    : constant String := Join (Src_Dir, "b.txt");
      A_Dest   : constant String := Join (Dest_Dir, "a.txt");
      B_Dest   : constant String := Join (Dest_Dir, "b.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Undone   : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (A_Src, "AAA");
      Write_File (B_Src, "BBB");

      Load := Files.File_System.Load_Directory (Src_Dir, Settings);
      Files.Model.Initialize (Model, Src_Dir, Load.Items, Root);
      Files.Model.Select_All_Visible (Model);

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Copy_To_Command, Model),
         "copy-to is enabled with a real selection");

      Routed := Files.Controller.Execute_Command (Files.Commands.Copy_To_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "copy-to command starts the picker");
      Assert (Files.Model.Tree_Panel_Is_Open (Model), "copy-to opens the folder tree");
      Assert (Files.Model.Tree_Pick_Is_Active (Model), "the destination picker is active");
      Assert
        (Files.Model.Tree_Pick_Mode_Of (Model) = Files.Model.Pick_Copy,
         "the picker records copy intent");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.Tree_Pick_Sources (Model).Length),
         2,
         "the picker captured both selected sources");

      Files.Model.Set_Tree_Pick_Target (Model, Dest_Dir);
      Confirm_Pick (Model, Settings);

      Assert (Ada.Directories.Exists (A_Dest), "a.txt is copied to the destination");
      Assert (Ada.Directories.Exists (B_Dest), "b.txt is copied to the destination");
      Assert (Ada.Directories.Exists (A_Src), "a.txt original is kept");
      Assert (Ada.Directories.Exists (B_Src), "b.txt original is kept");
      Assert (not Files.Model.Tree_Pick_Is_Active (Model), "confirming clears the picker");
      Assert (not Files.Model.Tree_Panel_Is_Open (Model), "confirming closes the folder tree");

      Undone := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Undone.Status, Files.Operations.Operation_Success, "the copy is undoable");
      Assert (not Ada.Directories.Exists (A_Dest), "undo removes the a.txt copy");
      Assert (not Ada.Directories.Exists (B_Dest), "undo removes the b.txt copy");
      Assert (Ada.Directories.Exists (A_Src), "undo keeps the a.txt original");
   end Test_Copy_To_Picker_Flow;
