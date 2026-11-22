with Files.Operations.Navigation;
with Files.Model.Recent;
with Files.Model.Filtering;
with Files.Operation_Results;
with Files.Settings.Path_References;
separate (Files_Suite.Operations)
   --  The recent view refreshes in place, and a move back from it that fails
   --  returns to it -- not to some other entry of the history.
   procedure Test_Recent_View_Refresh_And_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Folder   : constant String := Join (Root, "recent-rollback");
      Item     : constant String := Join (Folder, "opened.txt");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Step     : Files.Operation_Results.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Folder);
      Write_File (Item, "opened");
      Files.Settings.Path_References.Note_Recent (Settings, Item);
      Files.Model.Initialize (Model, Folder, Files.Items.Item_Vectors.Empty_Vector, Root);
      Files_Suite.Support.Discard (Files.Operations.Refresh (Model, Settings));
      Files_Suite.Support.Discard (Files.Operations.Navigation.Navigate_Recent (Model, Settings));
      Assert (Files.Model.Recent.In_Recent_View (Model), "the recent view is open");

      --  A refresh (Clear Recent, a finished job) swaps the items, not the view.
      Files.Model.Filtering.Set_Filter (Model, "open");
      Files_Suite.Support.Discard (Files.Operations.Navigation.Navigate_Recent (Model, Settings));
      Assert (Files.Model.Recent.In_Recent_View (Model), "a refresh keeps the recent view");
      Files_Suite.Support.Assert_Equal (Files.Model.Filtering.Filter_Text (Model), "open",
                                        "a refresh keeps the view's filter");
      Assert (Files.Model.Can_Go_Back (Model), "and the way back");

      --  The folder it came from is gone: Back fails and stays in Recent.
      Project_Tools.Files.Delete_Tree (Folder);
      Step := Files.Operations.Navigation.Navigate_Back (Model, Settings);
      Assert (Step.Status /= Files.Operation_Results.Operation_Success, "back to a folder that is gone fails");
      Assert (Files.Model.Recent.In_Recent_View (Model), "the failed move returns to the recent view");
      Files_Suite.Support.Assert_Equal (Files.Model.Current_Path (Model), "", "with the recent view's empty path");
      Assert (Files.Model.Can_Go_Back (Model), "and the history it had");
      Assert (not Files.Model.Can_Go_Forward (Model), "with nothing added ahead of it");
      Reset_Root;
   end Test_Recent_View_Refresh_And_Rollback;
