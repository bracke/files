with Files.Model.Info_Pane;
with Files_Suite.Listings;
with Files_Suite.Support.Disk;
separate (Files_Suite.Interaction)
   --  Text typed into the window (Interaction.Append_Text, the window's
   --  type-ahead) moves the grid's selection to the item it names, and ends
   --  as every dispatch does (Controller.Finish_Dispatch): the selected
   --  item's details are read, as after a key press.
   procedure Test_Typed_Text_Finishes_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Folder   : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "typed");
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      Ada.Directories.Create_Path (Folder);
      Files_Suite.Support.Disk.Write_File (Files_Suite.Support.Disk.Join (Folder, "alpha.txt"), "a");
      Files_Suite.Support.Disk.Write_File (Files_Suite.Support.Disk.Join (Folder, "bravo.txt"), "b");
      Files.Model.Initialize
        (Model, Folder, Files_Suite.Listings.Load_Directory (Folder, Settings).Items, Folder);
      Files.Model.Info_Pane.Toggle_Info_Pane (Model);
      Assert (Files.Model.Selection.Selected_Count (Model) = 0, "nothing is selected yet");

      Files.Interaction.Append_Text (Model, Settings, "", "br", Result);
      Assert (Files.Model.Selection.Selected_Count (Model) = 1
              and then Ada.Directories.Simple_Name
                         (Ada.Strings.Unbounded.To_String (Files.Model.Selection.Selected_Item (Model).Full_Path))
                       = "bravo.txt",
              "typing in the grid selects the item it names");
      Assert (not Files.Model.Info_Pane.Selected_Item_Needs_Extra (Model),
              "and the dispatch reads the selected item's details");
      Files_Suite.Support.Disk.Reset_Root;
   end Test_Typed_Text_Finishes_Dispatch;
