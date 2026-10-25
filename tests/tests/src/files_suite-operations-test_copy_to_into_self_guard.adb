separate (Files_Suite.Operations)
   procedure Test_Copy_To_Into_Self_Guard (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir   : constant String := Join (Root, "selfguard-src");
      Box_Dir   : constant String := Join (Src_Dir, "box");
      Retry_Dir : constant String := Join (Root, "selfguard-retry");
      Inside    : constant String := Join (Box_Dir, "inside.txt");
      Load      : Files.File_System.Directory_Load_Result;
      Model     : Files.Model.Window_Model;
      Routed    : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Box_Dir);
      Ada.Directories.Create_Path (Retry_Dir);
      Write_File (Inside, "IN");

      Load := Files.File_System.Load_Directory (Src_Dir, Settings);
      Files.Model.Initialize (Model, Src_Dir, Load.Items, Root);
      Select_Name (Model, "box");

      Routed := Files.Controller.Execute_Command (Files.Commands.Copy_To_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "copy-to command starts the picker");

      --  Target the selected directory itself: copying it into itself must fail.
      Files.Model.Set_Tree_Pick_Target (Model, Box_Dir);
      Confirm_Pick (Model, Settings);

      Files_Suite.Support.Assert_Equal

        (Files.Model.Last_Error_Key (Model),

         "error.drop.into_self",

         "targeting inside the selection reports the into-self error");
      Assert (not Ada.Directories.Exists (Join (Box_Dir, "box")), "nothing is copied into the selected folder");
      Assert (Ada.Directories.Exists (Inside), "the selected folder is unchanged");

      Assert
        (Files.Model.Tree_Pick_Is_Active (Model)
         and then Files.Model.Tree_Panel_Is_Open (Model),
         "a rejected destination leaves the picker open for correction");
      Files.Model.Set_Tree_Pick_Target (Model, Retry_Dir);
      Confirm_Pick (Model, Settings);
      Assert
        (Ada.Directories.Exists (Join (Retry_Dir, "box")),
         "choosing a valid destination after the rejection completes the copy");
      Assert
        (not Files.Model.Tree_Pick_Is_Active (Model)
         and then not Files.Model.Tree_Panel_Is_Open (Model),
         "a successful retry closes the destination picker");
   end Test_Copy_To_Into_Self_Guard;
