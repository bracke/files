with Files.Items;
separate (Files_Suite.Operations)
   --  A relative path typed into the path bar is taken from the folder on
   --  screen, not from the directory the program was started in.
   procedure Test_Path_Input_Relative_To_View (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Shown    : constant String := Join (Root, "shown");
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Shown, "inner"));
      Ada.Directories.Create_Path (Join (Root, "beside"));
      Files.Model.Initialize (Model, Shown, Files.Items.Item_Vectors.Empty_Vector, Root);
      Files.Model.Set_Path_Input_Text (Model, "inner");
      Result := Files.Operations.Commit_Path_Input (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Operations.Operation_Navigated, "a relative child path is opened");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Join (Shown, "inner")),
         "the child of the folder on screen is opened");
      Files.Model.Set_Path_Input_Text (Model, Join ("..", Join ("..", "beside")));
      Result := Files.Operations.Commit_Path_Input (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Operations.Operation_Navigated, "a path through .. is opened");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Join (Root, "beside")),
         ".. climbs from the folder on screen");
   end Test_Path_Input_Relative_To_View;
