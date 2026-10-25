separate (Files_Suite.Operations)
   procedure Test_Info_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Routed : Files.Interaction.Interaction_Result;
      Applied : Boolean;
      Revision : Natural;
   begin
      for Unsupported in Boolean loop
         Reset_Root;
         Write_Binary_File (Join (Root, "selected.bin"), "binary data");
         Write_Binary_File (Join (Root, "selected.txt"), "text data");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Set_Background_Transfers (Model, True);
         Select_Name (Model, (if Unsupported then "selected.bin" else "selected.txt"));
         Files.Model.Toggle_Info_Pane (Model);
         Write_Binary_File (Join (Root, "new.txt"), "new");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "",
            (Kind => Files.Events.Command_Input_Action, Command => Files.Commands.Refresh_Directory_Command,
             others => <>), 16, Guikit.Input.No_Modifiers, Routed);
         Assert (Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)), "the refresh is scheduled");
         Applied := False;
         for Attempt in Files_Suite.Support.Polling loop
            Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
            exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
         end loop;
         Assert (Applied and then Files.Model.Item_Count (Model) = 3,
                 "info metadata cannot invalidate a manual refresh started by the same action");
         Files.Operations.Ensure_Selected_Item_Extra (Model);
         Assert (Files.Model.Selected_Item (Model).Filetype_Extra_Loaded, "even an empty metadata result is cached");
         Revision := Files.Model.Revision (Model);
         for Attempt in 1 .. 20 loop
            Files.Operations.Ensure_Selected_Item_Extra (Model);
         end loop;
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model),
            Revision,
            "cached metadata does not repeatedly change the revision");
      end loop;
   exception
      when others => Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Info_Refresh;
