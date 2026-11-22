with Files.Operation_Results;
with Files.Model.Creation;
with Files.Model.Rename;
with Files.Items;
with Files.Settings.Testing;
separate (Files_Suite.Model)
   procedure Test_Create_Row_Uses_Settings_Maps (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.Items.Item_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;

      function Row return Files.Items.Directory_Item is (Files.Model.Visible_Item (Model, 1));
   begin
      Reset_Root;
      Files.Settings.Testing.Add_Extension_Mapping (Settings, "notes", "text/x-notes");
      Files.Settings.Testing.Add_Icon_Mapping (Settings, "text/x-notes", "ada");
      Files.Model.Initialize (Model, Root, Items, Root);
      Result := Files.Controller.Execute_Non_Settings_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status, Files.Operation_Results.Operation_Success, "the create command opens a new row");
      Assert (Files.Model.Creation.Temporary_Item_Is_Active (Model), "the new row is being named");

      --  Named into the user's mapping, the row reads as a listing of the
      --  same name would.
      Files.Model.Rename.Set_Text (Model, "plan.notes");
      Files_Suite.Support.Assert_Equal (To_String (Row.Filetype), "text/x-notes", "the row takes the mapped type");
      Files_Suite.Support.Assert_Equal (To_String (Row.Icon_Id), "ada", "and the mapped icon");

      --  Mappings changed while it is named classify it afresh.
      Settings := Files.Settings.Default_Settings;
      Files.Model.Reapply_Listing_Settings (Model, Settings, Reclassify => True);
      Assert (To_String (Row.Filetype) /= "text/x-notes", "a dropped mapping no longer types the row");
   end Test_Create_Row_Uses_Settings_Maps;
