separate (Files_Suite.Operations)
   procedure Test_Apply_Ui_State_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      procedure Check
        (Field        : Files.Settings.Sort_Field;
         Ascending    : Boolean;
         Expect_Model : Files.Model.Sort_Field;
         Label        : String)
      is
         Model    : Files.Model.Window_Model := Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Settings.Default_View     := Files.Types.Details;
         Settings.Sort_Field_Value := Field;
         Settings.Sort_Ascending   := Ascending;
         Files.Operations.Apply_Ui_State (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Files.Model.View_Mode_Of (Model),
            Files.Types.Details,
            Label & ": view mode applied");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Sort_Field_Of (Model),
            Expect_Model,
            Label & ": sort field applied");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Sort_Is_Ascending (Model),
            Ascending,
            Label & ": sort direction applied");
      end Check;
   begin
      --  Every field/direction combination applies exactly. The regression case is
      --  the default field (name) ascending: the previous toggle-based apply flipped
      --  it to descending, leaving the model out of step with the settings so a later
      --  user toggle merely undid the discrepancy and never persisted.
      Check (Files.Settings.Sort_By_Name, True,  Files.Model.Sort_Name, "name ascending");
      Check (Files.Settings.Sort_By_Name, False, Files.Model.Sort_Name, "name descending");
      Check (Files.Settings.Sort_By_Size, True,  Files.Model.Sort_Size, "size ascending");
      Check (Files.Settings.Sort_By_Size, False, Files.Model.Sort_Size, "size descending");
   end Test_Apply_Ui_State_Round_Trip;
