separate (Files_Suite.Operations)
   procedure Test_Move_To_Picker_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "moveto-src");
      Dest_Dir : constant String := Join (Root, "moveto-dest");
      A_Src    : constant String := Join (Src_Dir, "a.txt");
      A_Dest   : constant String := Join (Dest_Dir, "a.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Undone   : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (A_Src, "AAA");

      Load := Files.File_System.Load_Directory (Src_Dir, Settings);
      Files.Model.Initialize (Model, Src_Dir, Load.Items, Root);
      Select_Name (Model, "a.txt");

      Routed := Files.Controller.Execute_Command (Files.Commands.Move_To_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success, "move-to command starts the picker");
      Assert
        (Files.Model.Tree_Pick_Mode_Of (Model) = Files.Model.Pick_Move,
         "the picker records move intent");

      Files.Model.Set_Tree_Pick_Target (Model, Dest_Dir);
      Confirm_Pick (Model, Settings);

      Assert (Ada.Directories.Exists (A_Dest), "a.txt is moved to the destination");
      Assert (not Ada.Directories.Exists (A_Src), "a.txt is removed from the source");

      Undone := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Undone.Status = Files.Operations.Operation_Success, "the move is undoable");
      Assert (Ada.Directories.Exists (A_Src), "undo returns a.txt to the source");
      Assert (not Ada.Directories.Exists (A_Dest), "undo removes a.txt from the destination");
   end Test_Move_To_Picker_Flow;
