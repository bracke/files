with Files.Quick_Look.Preparation;
with Files.Model.Filtering;
with Files_Suite.Listings;
with Files.UI_Types;
with Files.Preference_Types;
with Files.Controller.Testing;
with Files.Model.Quick_Look;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Models;
separate (Files_Suite.Interaction)
   --  Settings shared from another window reach this one without losing
   --  what is in progress here, and without making a stale value win later:
   --  over search results a rename and Quick Look survive a hidden-files
   --  change; a folder view takes a shared sort (so a later sort or view
   --  command here does not write the old order back), and a command here
   --  writes back only what it changed, not this window's own view mode.
   procedure Test_Shared_Settings_Keep_Edits_And_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Files_Suite.Support;
      use Files_Suite.Support.Disk;
      use Files_Suite.Support.Models;
      use type Files.Types.Sort_Field;
      use type Files.Preference_Types.View_Mode;
      Model    : Files.Model.Window_Model;
      Other    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Shared   : Files.Settings.Settings_Model;
      Outcome  : Files.Controller.Controller_Result with Unreferenced;
      Result   : Files.Interaction.Interaction_Result;

      procedure Load (Into : in out Files.Model.Window_Model) is
         Load_Result : constant Files.File_System.Directory_Load_Result :=
           Files_Suite.Listings.Load_Directory (Root, Settings);
      begin
         Files.Model.Initialize (Into, Directory_Path => Root, Items => Load_Result.Items, Home_Path => "/home/test");
      end Load;
   begin
      Reset_Root;
      Write_File (Join (Root, "Alpha.txt"));
      Write_File (Join (Root, "Beta.txt"), "longer content");
      Write_File (Join (Root, ".hidden_two"));
      Settings.Show_Hidden_Files := True;
      Load (Model);
      Files.Model.Filtering.Note_Search_Results (Model, Files.UI_Types.Search_Names);

      --  A rename in progress over the results.
      Select_Name (Model, "Beta.txt");
      Outcome := Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Files.Controller.Testing.Replace_Focused_Text (Model, "Beta-2.txt");
      Shared := Settings;
      Shared.Show_Hidden_Files := False;
      Files.Interaction.Adopt_Shared_Settings (Model, Settings, Shared);
      Assert (Files.Model.Rename.Is_Active (Model), "the rename survives a shared hidden-files change");
      Assert (Files.Model.Rename.Text (Model) = "Beta-2.txt", "with the name typed so far");
      Assert_Equal (Files.Model.Focus (Model), Files.UI_Types.Focus_Rename_Input, "and keeps the keyboard");
      Assert_Equal (Files.Model.Visible_Count (Model), 2, "while the hidden result leaves the view");
      Outcome := Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);

      --  Quick Look on a result.
      Files.Model.Quick_Look.Open
        (Model, Files.Quick_Look.Preparation.Prepare (Files.Model.Selection.Selected_Item (Model)));
      Shared := Settings;
      Shared.Show_Hidden_Files := True;
      Files.Interaction.Adopt_Shared_Settings (Model, Settings, Shared);
      Assert (Files.Model.Quick_Look.Is_Open (Model), "Quick Look on a still-selected result stays open");
      Assert_Equal (Files.Model.Visible_Count (Model), 3, "and the hidden result is back");
      Files.Model.Quick_Look.Close (Model);

      --  Two folder views share one settings file. The first sorts by size
      --  and switches to details; the second adopts.
      Settings := Files.Settings.Default_Settings;
      Load (Model);
      Load (Other);
      declare
         Other_Settings : Files.Settings.Settings_Model := Settings;
      begin
         Files.Interaction.Execute_Command
           (Other, Other_Settings, "", Files.Commands.Sort_By_Size_Command, Result => Result);
         Files.Interaction.Execute_Command
           (Other, Other_Settings, "", Files.Commands.Select_Details_Command, Result => Result);
         Assert (Other_Settings.Sort_Field_Value = Files.Types.Sort_Size, "the first window sorts by size");
         Assert (Other_Settings.Default_View = Files.Preference_Types.Details, "and remembers details");
         Files.Interaction.Adopt_Shared_Settings (Model, Settings, Other_Settings);
      end;
      Assert (Files.Model.Sort_Field_Of (Model) = Files.Types.Sort_Size,
              "the second window, showing a folder, takes the shared sort");
      Assert (Files.Model.View_Mode_Of (Model) /= Files.Preference_Types.Details,
              "but keeps its own view mode");

      --  A command here that changes neither the order nor the view writes
      --  back only the info pane: the shared sort and view mode stay.
      Files.Interaction.Execute_Command
        (Model, Settings, "", Files.Commands.Toggle_Info_Pane_Command, Result => Result);
      Assert (Settings.Info_Pane_Open, "the info pane change is written");
      Assert (Settings.Sort_Field_Value = Files.Types.Sort_Size, "the shared sort is not written back over");
      Assert (Settings.Default_View = Files.Preference_Types.Details, "nor is the shared view mode");
      Reset_Root;
   end Test_Shared_Settings_Keep_Edits_And_Order;
