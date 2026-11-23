with Files.Controller;
with Files.Model.Info_Pane;
with Files.Model.Filtering;
with Files_Suite.Listings;
with Files.UI_Types;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Models;
separate (Files_Suite.Interaction)
   --  Hiding hidden files from another window deleted the hidden matches
   --  from the search results a window showed, so showing them again could
   --  not bring them back, and the info pane lost its place. The results
   --  now keep every match and leave hidden ones out of view while the
   --  setting hides them; the info pane keeps its scroll both ways.
   procedure Test_Shared_Hidden_Toggle_Restores_Results (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Files_Suite.Support;
      use Files_Suite.Support.Models;
      use Files_Suite.Support.Disk;
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Shared   : Files.Settings.Settings_Model;

      function Selected_Name return String is
        (Ada.Strings.Unbounded.To_String (Files.Model.Selection.Selected_Item (Model).Name));
   begin
      Reset_Root;
      Write_File (Join (Root, "Alpha.txt"));
      Write_File (Join (Root, "Beta.txt"));
      Write_File (Join (Root, ".hidden_two"));
      Settings.Show_Hidden_Files := True;
      declare
         Load_Result : constant Files.File_System.Directory_Load_Result :=
           Files_Suite.Listings.Load_Directory (Root, Settings);
      begin
         Files.Model.Initialize (Model, Directory_Path => Root, Items => Load_Result.Items, Home_Path => "/home/test");
      end;
      Files.Model.Filtering.Note_Search_Results (Model, Files.UI_Types.Search_Names);
      Assert_Equal (Files.Model.Visible_Count (Model), 3, "the results hold the hidden match");
      Select_Name (Model, "Beta.txt");
      Files.Model.Info_Pane.Set_Info_Pane_Scroll_Lines (Model, 4);

      --  Another window hides hidden files.
      Shared := Settings;
      Shared.Show_Hidden_Files := False;
      Files.Controller.Adopt_Shared_Settings (Model, Settings, Shared);
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model), "the window still shows its search results");
      Assert_Equal (Files.Model.Visible_Count (Model), 2, "the hidden match leaves the view");
      Assert_Equal (Files.Model.Item_Count (Model), 3, "but stays among the results");
      Assert (Files.Model.Visible_Index_Of (Model, Join (Root, ".hidden_two")) = 0, "the hidden match is not a row");
      Assert (Selected_Name = "Beta.txt", "the selection stays");
      Assert_Equal (Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model), 4, "the info pane keeps its scroll");

      --  And shows them again: the hidden match comes back without a search.
      Shared := Settings;
      Shared.Show_Hidden_Files := True;
      Files.Controller.Adopt_Shared_Settings (Model, Settings, Shared);
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model), "the results stay when hidden files show again");
      Assert_Equal (Files.Model.Visible_Count (Model), 3, "the hidden match is back in view");
      Assert (Files.Model.Visible_Index_Of (Model, Join (Root, ".hidden_two")) > 0, "as a row of its own");
      Assert (Selected_Name = "Beta.txt", "the selection stays again");
      Assert_Equal (Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model), 4, "and so does the info pane's scroll");

      --  A selected hidden match that leaves the view leaves the selection.
      Select_Name (Model, ".hidden_two");
      Shared := Settings;
      Shared.Show_Hidden_Files := False;
      Files.Controller.Adopt_Shared_Settings (Model, Settings, Shared);
      Assert (Files.Model.Selection.Selected_Count (Model) = 0, "a hidden selection is dropped once out of view");
      Reset_Root;
   end Test_Shared_Hidden_Toggle_Restores_Results;
