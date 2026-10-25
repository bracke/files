separate (Files_Suite.Commands)
   procedure Test_Save_Settings_Applies_Live (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Path     : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "save-live.conf");
      Result   : Files.Controller.Controller_Result;
   begin
      Files_Suite.Support.Reset_Root;

      --  Sample_Model opens in the small-icons view sorted ascending by name.
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Small_Icons,
         "model starts in small-icons view");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Field_Of (Model),
         Files.Model.Sort_Name,
         "model starts sorted by name");
      Assert (Files.Model.Sort_Is_Ascending (Model), "model starts sorted ascending");

      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "the settings pane opens with an editable draft");

      --  Edit the draft to a different view, sort field, and direction.
      declare
         Draft : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
      begin
         Draft.Default_View_Mode := Ada.Strings.Unbounded.To_Unbounded_String ("details");
         Draft.Sort_Field_Value  := Ada.Strings.Unbounded.To_Unbounded_String ("size");
         Draft.Sort_Ascending    := Ada.Strings.Unbounded.To_Unbounded_String ("false");
         Files.Model.Set_Settings_Draft (Model, Draft);
      end;

      Result := Files.Controller.Save_Settings (Model, Settings, Path);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "saving the settings succeeds");

      --  The change takes effect on the live model immediately, not only on the
      --  next launch.
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Details,
         "the saved view mode is applied live");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Field_Of (Model),
         Files.Model.Sort_Size,
         "the saved sort field is applied live");
      Assert (not Files.Model.Sort_Is_Ascending (Model), "the saved sort direction is applied live");
   end Test_Save_Settings_Applies_Live;
