separate (Files_Suite.Model)
   procedure Test_Root_Selector_Row_Activation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Roots_A  : Files.Types.String_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
      Files.Model.Initialize (Model, Root, Sample_Items, Root);
      Roots_A.Append (To_Unbounded_String (Root));
      Roots_A.Append (To_Unbounded_String (Target));
      Roots_A.Append (To_Unbounded_String (Ada.Directories.Full_Name (Root)));
      --  Row 2 is Target.
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Files.Model.Set_Root_Selected_Index (Model, 2);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Selected_Root_Command,
         "Return activates selected root row");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "Return root activation navigates");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Target),
         "Return loads selected root");

      Files.Model.Initialize (Model, Root, Sample_Items, Root);
      Roots_A.Clear;
      Roots_A.Append (To_Unbounded_String (Target));
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, "/tmp/root-click-edit");
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Result := Files.Controller.Handle_Root_Click (Model, Settings, Root_Index => 1);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Selected_Root_Command,
         "root row click reports root activation command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "root row click navigates");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Target),
         "root row click loads root");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "root row click clears path input focus");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         Ada.Directories.Full_Name (Target),
         "root row click replaces edited path text");
   end Test_Root_Selector_Row_Activation;
