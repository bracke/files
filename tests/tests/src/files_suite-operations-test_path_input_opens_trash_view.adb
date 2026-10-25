separate (Files_Suite.Operations)
   --  Typing the trash's path into the path bar opens the trash view, as
   --  navigating to it any other way does.
   procedure Test_Path_Input_Opens_Trash_View (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      procedure Check is
         Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Model    : Files.Model.Window_Model;
         Trashed  : Files.Types.UString;
         Result   : Files.Operations.Operation_Result;
      begin
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Write_File (Join (Root, "path-input-trash.txt"));
         Assert (Files.File_System.Move_To_Trash (Join (Root, "path-input-trash.txt"), Trashed).Success,
                 "something is in the trash");
         Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Files.Model.Set_Path_Input_Text (Model, Files.File_System.Trash_Files_Directory);
         Result := Files.Operations.Commit_Path_Input (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Result.Status, Files.Operations.Operation_Navigated, "the typed path is opened");
         Assert (Files.Model.Current_Is_Trash (Model), "the folder typed in is shown as the trash");
         Assert (Files.Commands.Is_Enabled (Files.Commands.Empty_Trash_Command, Model),
                 "so Empty Trash is offered there");
      end Check;
   begin
      Reset_Root;
      With_Trash_Environment (Check'Access);
   end Test_Path_Input_Opens_Trash_View;
