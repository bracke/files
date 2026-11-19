with Guikit.Input;
with Files.Operation_Results;
separate (Files_Suite.Transfer)
   procedure Test_Item_Drop_Starts_Paste (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Controller.Controller_Status;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Folder   : constant String := Join (Root, "item-drop");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Outcome  : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Folder, "target"));
      Write_File (Join (Folder, "moved.txt"), "moved");
      Write_File (Join (Folder, "other.txt"), "other");
      Load := Files.File_System.Load_Directory (Folder, Settings);
      Files.Model.Initialize (Model, Folder, Load.Items, Root);
      Files.Model.Selection.Select_Visible (Model, Files.Model.Visible_Index_Of (Model, Join (Folder, "moved.txt")));

      Outcome :=
        Files.Controller.Handle_Item_Drop
          (Model, Settings, Files.Model.Visible_Index_Of (Model, Join (Folder, "other.txt")),
           Guikit.Input.No_Modifiers);
      Assert (Outcome.Status = Files.Controller.Controller_Ignored, "a drop on a file is ignored");
      Assert (Ada.Directories.Exists (Join (Folder, "moved.txt")), "a drop on a file moves nothing");

      Outcome :=
        Files.Controller.Handle_Item_Drop
          (Model, Settings, Files.Model.Visible_Index_Of (Model, Join (Folder, "target")),
           Guikit.Input.No_Modifiers);
      Assert (Outcome.Status = Files.Controller.Controller_Command_Executed, "a drop on a folder starts a paste");
      Assert (Outcome.Command = Files.Commands.Move_To_Command, "a drop without Ctrl reports a move");
      Files_Suite.Support.Assert_Equal
        (Outcome.Operation.Status, Files.Operation_Results.Operation_Success, "the dropped paste succeeds");
      Assert
        (Ada.Directories.Exists (Join (Join (Folder, "target"), "moved.txt")),
         "the dropped selection lands in the folder dropped on");
      Assert (not Ada.Directories.Exists (Join (Folder, "moved.txt")), "a drop without Ctrl moves the selection");
   end Test_Item_Drop_Starts_Paste;
