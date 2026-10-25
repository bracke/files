separate (Files_Suite.Model)
   procedure Test_Path_Input_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model   : Files.Model.Window_Model := Sample_Model;
      Empty   : Files.File_System.Item_Vectors.Vector;
      Invalid : constant Files.File_System.Path_Result :=
        (Status         => Files.File_System.Path_Missing,
         Directory_Path => Null_Unbounded_String,
         Error_Key      => To_Unbounded_String ("error.path.missing"));
      Valid   : constant Files.File_System.Path_Result :=
        (Status         => Files.File_System.Path_Valid,
         Directory_Path => To_Unbounded_String ("/tmp/files_aunit/valid"),
         Error_Key      => Null_Unbounded_String);
   begin
      Files.Model.Focus_Path_Input (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "path input receives focus directly");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         Root,
         "path input focus restores current path text");
      Files.Model.Set_Path_Input_Text (Model, "/does/not/exist");
      Files.Model.Commit_Path_Input (Model, Invalid, Empty);
      Assert (not Files.Model.Path_Input_Is_Valid (Model), "invalid input sets validation state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Error_Key (Model),
         "error.path.missing",
         "invalid input records error key");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "invalid input does not change current path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "invalid path input keeps focus");
      Files.Model.Focus_Filter_Input (Model);
      Files.Model.Focus_Path_Input (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         Root,
         "refocus restores current path after invalid input");
      Assert (Files.Model.Path_Input_Is_Valid (Model), "refocus clears stale path validation state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Error_Key (Model),
         "",
         "refocus clears stale path validation error");
      Files.Model.Set_Path_Input_Text (Model, "/does/not/exist");
      Files.Model.Commit_Path_Input (Model, Invalid, Empty);
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files_Suite.Support.Assert_Equal (Files.Model.Path_Input_Text (Model), Root, "escape restores current path text");
      Assert (Files.Model.Path_Input_Is_Valid (Model), "escape clears path validation state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Error_Key (Model),
         "",
         "escape clears path validation error");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "escape clears path input focus");

      Files.Model.Open_Command_Palette (Model);
      Files.Model.Focus_Path_Input (Model);
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "path input focus closes command palette");
      Files.Model.Set_Path_Input_Text (Model, "/tmp/files_aunit/valid");
      Files.Model.Commit_Path_Input (Model, Valid, Empty);
      Assert (Files.Model.Path_Input_Is_Valid (Model), "valid input clears validation state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Error_Key (Model),
         "",
         "valid input clears validation error key");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         "/tmp/files_aunit/valid",
         "valid input changes path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "valid path input clears focus");
   end Test_Path_Input_Validation;
