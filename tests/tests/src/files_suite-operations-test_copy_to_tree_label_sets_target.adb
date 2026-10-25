separate (Files_Suite.Operations)
   procedure Test_Copy_To_Tree_Label_Sets_Target (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "label-src");
      Dest_Dir : constant String := Join (Root, "label-dest");
      A_Src    : constant String := Join (Src_Dir, "a.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Seeds    : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (A_Src, "AAA");

      Load := Files.File_System.Load_Directory (Src_Dir, Settings);
      Files.Model.Initialize (Model, Src_Dir, Load.Items, Root);
      Select_Name (Model, "a.txt");

      Routed := Files.Controller.Execute_Command (Files.Commands.Copy_To_Command, Model, Settings);
      Assert (Files.Model.Tree_Pick_Is_Active (Model), "the picker is active after the command");

      --  Reseed the tree with the destination as its only node so the label
      --  click has a deterministic target.
      Seeds.Append
        (Files.Folder_Tree.Entry_Seed'
           (Path => To_Unbounded_String (Dest_Dir), Name => To_Unbounded_String ("label-dest")));
      Files.Model.Seed_Tree (Model, Seeds);

      --  A label click (Toggle => False) while picking sets the target and must
      --  not navigate the main view away from the source directory.
      Routed := Files.Controller.Handle_Tree_Click (Model, Settings, 1, Toggle => False);
      Files_Suite.Support.Assert_Equal
        (Routed.Status,
         Files.Controller.Controller_Command_Executed,
         "the label click is handled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Tree_Pick_Target (Model),
         Dest_Dir,
         "the label click sets the highlighted target");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Src_Dir,
         "the label click does not navigate the main view");
      Assert (Files.Model.Tree_Pick_Is_Active (Model), "the picker stays active after choosing a target");
   end Test_Copy_To_Tree_Label_Sets_Target;
