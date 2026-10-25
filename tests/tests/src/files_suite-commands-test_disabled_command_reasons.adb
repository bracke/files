separate (Files_Suite.Commands)
   --  Files.Commands.Status_Of is the one set of enablement rules; the
   --  controller's disabled-command report names the check that failed instead
   --  of a misleading "...failed" key.
   procedure Test_Disabled_Command_Reasons (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;

      procedure Expect (Id : Files.Commands.Command_Id; Key : String; Context : String) is
         Status : constant Files.Commands.Command_Status := Files.Commands.Status_Of (Id, Model);
      begin
         Assert (not Status.Enabled, Context & ": the command is disabled");
         Assert (Status.Enabled = Files.Commands.Is_Enabled (Id, Model), Context & ": Is_Enabled agrees");
         Files_Suite.Support.Assert_Equal (Files.Commands.Reason_Key (Status.Reason), Key, Context & ": reason");
         Files.Model.Set_Error (Model, "");
         Result := Files.Controller.Execute_Command (Id, Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Result.Status, Files.Controller.Controller_Ignored, Context & ": the controller ignores it");
         Files_Suite.Support.Assert_Equal (Files.Model.Last_Error_Key (Model), Key, Context & ": error line");
         Files_Suite.Support.Assert_Equal (To_String (Result.Operation.Error_Key), Key, Context & ": result key");
      end Expect;
   begin
      --  A plain file selected: Extract says there is no archive, not that it failed.
      Files.Model.Select_Visible (Model, 1);
      Expect (Files.Commands.Extract_Archive_Command, "error.extract.not_archive", "extract on a plain file");

      --  An empty clipboard is named as such.
      Expect (Files.Commands.Paste_Items_Command, "error.clipboard.empty", "paste with an empty clipboard");

      --  In the trash view the selection commands say why, whatever they are.
      Files.Model.Set_Current_Is_Trash (Model, True);
      Expect (Files.Commands.Delete_Selected_Items_Command, "error.command.trash_view", "delete in the trash");
      Expect (Files.Commands.Cut_Selected_Items_Command, "error.command.trash_view", "cut in the trash");
      Expect (Files.Commands.Duplicate_Selected_Command, "error.command.trash_view", "duplicate in the trash");
      Expect (Files.Commands.Compress_Zip_Command, "error.command.trash_view", "compress in the trash");
      Files.Model.Set_Current_Is_Trash (Model, False);

      --  Nothing to say: a disabled undo stays silent.
      declare
         Status : constant Files.Commands.Command_Status :=
           Files.Commands.Status_Of (Files.Commands.Undo_Command, Model);
      begin
         Assert (not Status.Enabled, "undo is disabled without history");
         Files_Suite.Support.Assert_Equal
           (Files.Commands.Reason_Key (Status.Reason), "", "a disabled undo has nothing to report");
      end;

      --  The recent view: a search names the view, not a directory load error.
      Files.Model.Navigate_Recent (Model, Files.File_System.Item_Vectors.Empty_Vector);
      Files.Model.Set_Filter (Model, "alpha");
      Expect (Files.Commands.Search_Recursive_Command, "error.command.recent_view", "search in the recent view");

      --  An enabled command has no reason.
      Assert (Files.Commands.Status_Of (Files.Commands.Navigate_Recent_Command, Model).Enabled,
              "the recent view stays reachable");
   end Test_Disabled_Command_Reasons;
