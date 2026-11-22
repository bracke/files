with Files_Suite.Listings;
with Files.Model.Jobs;
with Files.Input_Actions;
separate (Files_Suite.Refresh)
   --  A session whose settings file failed to load marks its settings as not
   --  to be saved. That mark is session state, never in a job request, so it
   --  must not make every background result look out of date: the refresh
   --  applies, once, instead of being re-requested for ever.
   procedure Test_Refresh_Applies_With_Refused_Settings (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Routed   : Files.Interaction.Interaction_Result;
      Applied  : Boolean := False;
   begin
      Settings.Persistence_Refused := True;
      Reset_Root;
      Write_Binary_File (Join (Root, "first.txt"), "first");
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
      Write_Binary_File (Join (Root, "second.txt"), "second");
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "",
         (Kind => Files.Input_Actions.Command_Input_Action, Command => Files.Commands.Refresh_Directory_Command),
         Guikit.Input.No_Modifiers, Routed);
      Await_View (Model, Settings, Applied);
      Assert (not Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model)),
              "the refresh finishes instead of being requested again");
      Assert (Applied, "its result applies");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 2, "the new file is listed");
   exception
      when others => Files.Refresh.Cancel (Model); raise;
   end Test_Refresh_Applies_With_Refused_Settings;
