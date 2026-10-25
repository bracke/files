separate (Files_Suite.Model)
   --  Owner and group names reach the info pane through the model: the window
   --  layer samples them (Files.Application.Sample_Account_Names) and
   --  Build_Snapshot only reads them, so building a snapshot makes no NSS
   --  lookup. Unsampled, the pane gets no name and falls back to the number.
   procedure Test_Snapshot_Owner_Names_From_Model (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Owned    : Files.File_System.Directory_Item :=
        Files.File_System.Make_Item (Root, "Owned.txt", Files.Types.Regular_File_Item, "text/plain");
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Revision : Natural;

      function Shown_Info return Files.Rendering.Info_Snapshot is
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
      begin
         Files_Suite.Support.Assert_Equal
           (Natural (Snapshot.Selected_Info.Length), 1, "the info pane lists the selected item");
         return Snapshot.Selected_Info.First_Element;
      end Shown_Info;
   begin
      Owned.Ownership_Available := True;
      Owned.Owner_Id := 0;
      Owned.Group_Id := 0;
      Items.Append (Owned);
      Files.Model.Initialize (Model, Directory_Path => Root, Items => Items, Home_Path => "/home/test");
      Select_Name (Model, "Owned.txt");
      if not Files.Model.Info_Pane_Is_Open (Model) then
         Files.Model.Toggle_Info_Pane (Model);
      end if;

      declare
         Info : constant Files.Rendering.Info_Snapshot := Shown_Info;
      begin
         Files_Suite.Support.Assert_Equal
           (To_String (Info.Owner_Name), "", "an unsampled owner has no name, so the pane shows the id");
         Files_Suite.Support.Assert_Equal
           (To_String (Info.Group_Name), "", "an unsampled group has no name, so the pane shows the id");
         Files_Suite.Support.Assert_Equal (Info.Owner_Id, 0, "the pane still carries the owner id");
      end;
      Assert (not Files.Model.Account_Names_Current (Model), "nothing has been sampled yet");

      Files.Application.Sample_Account_Names (Model);
      Assert (Files.Model.Account_Names_Current (Model), "the sample covers the model as it is");
      declare
         Info : constant Files.Rendering.Info_Snapshot := Shown_Info;
      begin
         Files_Suite.Support.Assert_Equal
           (To_String (Info.Owner_Name),
            Files.File_System.User_Name_For_Id (0),
            "the pane shows the owner name the window layer sampled");
         Files_Suite.Support.Assert_Equal
           (To_String (Info.Group_Name),
            Files.File_System.Group_Name_For_Id (0),
            "the pane shows the group name the window layer sampled");
      end;

      --  An unchanged name is not a change; a new one is, and is shown.
      Revision := Files.Model.Revision (Model);
      Files.Model.Set_Account_Name
        (Model, Files.Model.User_Account, 0, Files.File_System.User_Name_For_Id (0));
      Files_Suite.Support.Assert_Equal
        (Files.Model.Revision (Model), Revision, "recording the same name leaves the revision alone");
      Files.Model.Set_Account_Name (Model, Files.Model.User_Account, 0, "renamed_owner");
      Assert (Files.Model.Revision (Model) /= Revision, "a changed name bumps the revision so the view rebuilds");
      Files_Suite.Support.Assert_Equal
        (To_String (Shown_Info.Owner_Name), "renamed_owner", "the pane shows the newly recorded name");
      Assert (not Files.Model.Account_Names_Current (Model), "a changed model asks for a new sample");
   end Test_Snapshot_Owner_Names_From_Model;
