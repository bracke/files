separate (Files_Suite.Operations)
   procedure Test_Info_Selection_Completion (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Routed : Files.Interaction.Interaction_Result;
      Step : Files.Operations.Operation_Result;
      pragma Unreferenced (Step);
      Revision : Natural;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "a.txt"), "a bytes");
      Write_Binary_File (Join (Root, "b.txt"), "b bytes");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "a.txt");
      Files.Model.Toggle_Info_Pane (Model);
      Files.Operations.Ensure_Selected_Item_Extra (Model);
      Files.Interaction.Handle_Key
        (Model, Settings, "", Guikit.Input.Key_End, Guikit.Input.No_Modifiers, 16, Routed);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "b.txt",
         "keyboard selection populates details for the new selection: selection moved");
      Assert (Files.Model.Selected_Item (Model).Filetype_Extra_Loaded,
              "keyboard selection populates details for the new selection: details loaded");
      Assert (Length (Files.Model.Selected_Item (Model).Filetype_Extra) > 0,
              "keyboard selection populates details for the new selection: details present");
      Files.Model.Set_Background_Transfers (Model, True);
      Step := Files.Operations.Refresh (Model, Settings);
      Await_View (Model, Settings);
      Assert (Files.Model.Selected_Item (Model).Filetype_Extra_Loaded
              and then Length (Files.Model.Selected_Item (Model).Filetype_Extra) > 0,
              "completed refresh repopulates the selected item's details");
      Revision := Files.Model.Revision (Model);
      Files.Operations.Ensure_Selected_Item_Extra (Model);
      Files_Suite.Support.Assert_Equal (Revision, Files.Model.Revision (Model), "completed details remain cached");
   exception
      when others => Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Info_Selection_Completion;
