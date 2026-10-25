separate (Files_Suite.Operations)
   procedure Test_Copy_To_Cancel (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "cancel-src");
      Dest_Dir : constant String := Join (Root, "cancel-dest");
      A_Src    : constant String := Join (Src_Dir, "a.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (A_Src, "AAA");

      Load := Files.File_System.Load_Directory (Src_Dir, Settings);
      Files.Model.Initialize (Model, Src_Dir, Load.Items, Root);
      Select_Name (Model, "a.txt");

      Routed := Files.Controller.Execute_Command (Files.Commands.Copy_To_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "copy-to command starts the picker");
      Assert (Files.Model.Tree_Pick_Is_Active (Model), "the picker is active after the command");
      Files.Model.Set_Tree_Pick_Target (Model, Dest_Dir);

      --  Cancel is routed through the tree-toggle command (also used by the
      --  Cancel button and the panel close box): it closes the tree and clears
      --  the picker without writing anything.
      Routed := Files.Controller.Execute_Command (Files.Commands.Toggle_Folder_Tree_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Status,
         Files.Controller.Controller_Command_Executed,
         "the cancel command is executed");
      Assert (not Files.Model.Tree_Pick_Is_Active (Model), "cancelling clears the picker");
      Assert (not Files.Model.Tree_Panel_Is_Open (Model), "cancelling closes the folder tree");
      Assert (not Ada.Directories.Exists (Join (Dest_Dir, "a.txt")), "cancelling copies nothing");
      Assert (Ada.Directories.Exists (A_Src), "cancelling leaves the source unchanged");

      --  A queued Choose click can arrive after cancellation. It must not close
      --  a subsequently opened ordinary folder-tree panel.
      Files.Model.Open_Tree_Panel (Model);
      Confirm_Pick (Model, Settings);
      Assert
        (Files.Model.Tree_Panel_Is_Open (Model)
         and then not Files.Model.Tree_Pick_Is_Active (Model),
         "a stale picker-confirm action leaves an ordinary tree panel open");
   end Test_Copy_To_Cancel;
