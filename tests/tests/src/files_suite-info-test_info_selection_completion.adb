with Files_Suite.Listings;
with Files.Operation_Results;
with Files_Suite.Support.Models;
separate (Files_Suite.Info)
   procedure Test_Info_Selection_Completion (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Routed : Files.Interaction.Interaction_Result;
      Step : Files.Operation_Results.Operation_Result;
      pragma Unreferenced (Step);
      Revision : Natural;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "a.txt"), "a bytes");
      Write_Binary_File (Join (Root, "b.txt"), "b bytes");
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "a.txt");
      Files.Model.Toggle_Info_Pane (Model);
      Files.Refresh.Ensure_Selected_Item_Extra (Model, Show_Hidden => True);
      Files.Interaction.Handle_Key
        (Model, Settings, "", Guikit.Input.Key_End, Guikit.Input.No_Modifiers, Routed);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selection.Selected_Name (Model),
         "b.txt",
         "keyboard selection populates details for the new selection: selection moved");
      Assert (Files.Model.Selection.Selected_Item (Model).Filetype_Extra_Loaded,
              "keyboard selection populates details for the new selection: details loaded");
      Assert (Files_Suite.Support.Models.Describe (Files.Model.Selection.Selected_Item (Model).Filetype_Extra) /= "",
              "keyboard selection populates details for the new selection: details present");
      Files.Model.Set_Background_Transfers (Model, True);
      Step := Files.Operations.Refresh (Model, Settings);
      Await_View (Model, Settings);
      Await_Item_Details (Model);
      Assert (Files.Model.Selection.Selected_Item (Model).Filetype_Extra_Loaded
              and then Files_Suite.Support.Models.Describe
                (Files.Model.Selection.Selected_Item (Model).Filetype_Extra) /= "",
              "completed refresh repopulates the selected item's details");
      Revision := Files.Model.Revision (Model);
      Files.Application.Window_Polls.Poll_Selected_Item_Extra
        (Model, Files.Application.Extra_Info_Reader.Requester (77));
      Files_Suite.Support.Assert_Equal (Revision, Files.Model.Revision (Model), "completed details remain cached");
   exception
      when others => Files.Refresh.Cancel (Model); raise;
   end Test_Info_Selection_Completion;
