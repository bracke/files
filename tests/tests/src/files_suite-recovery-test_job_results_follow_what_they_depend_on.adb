with Files.Operation_Commands;
with Files.Settings.Path_References;
with Files_Suite.Support.Guards;
separate (Files_Suite.Recovery)
   --  A helper job's result is kept unless what it depends on changed while
   --  it ran: a zoom or a recent path shared from another window leaves a
   --  search's results standing, and a hidden-files change shared while a
   --  job runs still gets the window's listing read again once it is done.
   procedure Test_Job_Results_Follow_What_They_Depend_On (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Changed  : Files.Settings.Settings_Model := Settings;
      Model    : aliased Files.Model.Window_Model;
      Paste    : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result with Unreferenced;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "a.txt"), "needle");
      Write_Binary_File (Join (Root, "needle.txt"), "x");
      Write_Binary_File (Join (Root, ".needle-hidden"), "x");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);

      --  Another window zooms and opens a file while the search runs.
      Files.Model.Set_Filter (Model, "needle");
      Step := Files.Operation_Commands.Run_Search (Model, Settings, Files.Types.Search_Names);
      Assert (Files.Model.Foreground_Job_Is_Active (Model), "the search runs as the window's job");
      Changed.Font_Pixel_Size := Settings.Font_Pixel_Size + 4;
      Files.Settings.Path_References.Note_Recent (Changed, Join (Root, "a.txt"));
      Step := Files_Suite.Support.Models.Finish_Paste (Model, Changed);
      Assert (Files.Model.Search_Results_Are_Active (Model),
              "the search's results stand though unrelated settings changed while it ran");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 1, "with its one match");

      --  Back to the folder; a job runs while hidden files are shown elsewhere.
      Files.Model.Set_Filter (Model, "");
      Files.Model.Clear_Search_Results (Model);
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Replace_Items (Model, Load.Items);
      Select_Name (Model, "a.txt");
      Step := Files.Operation_Commands.Duplicate_Selected (Model, Settings);
      Assert (Files.Model.Foreground_Job_Is_Active (Model), "the duplicate runs as the window's job");
      Changed := Settings;
      Changed.Show_Hidden_Files := True;
      --  What Adopt_Shared_Settings asks for: a read under the new policy.
      Step := Files.Refresh_Jobs.Start (Model, Changed, Force => False);
      Assert (Files.Model.Refresh_Is_Owed (Model),
              "a read declined while the job runs is owed, not dropped");
      Step := Files_Suite.Support.Models.Finish_Paste (Model, Changed);
      Assert (Files.Model.Refresh_Is_Owed (Model),
              "after the job the read is still owed, so the window lists under the new policy next");
      Reset_Root;
   end Test_Job_Results_Follow_What_They_Depend_On;
