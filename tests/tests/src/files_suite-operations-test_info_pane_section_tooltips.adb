separate (Files_Suite.Operations)
   procedure Test_Info_Pane_Section_Tooltips (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;

      function Tooltip_Present (Text : String) return Boolean is
      begin
         for Tip of Frame.Tooltips loop
            if To_String (Tip.Text) = Text then
               return True;
            end if;
         end loop;
         return False;
      end Tooltip_Present;
   begin
      Reset_Root;
      Write_File (Join (Root, "tip.txt"), "hello");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "tip.txt");
      Files.Model.Toggle_Info_Pane (Model);

      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 2000, Height => 1200, Line_Height => 20);

      Assert (Tooltip_Present (Files.Localization.Text ("info.permissions.tooltip")),
              "the Permissions section has its descriptive tooltip");
      Assert (Tooltip_Present (Files.Localization.Text ("info.filetype.tooltip")),
              "the Filetype section has its descriptive tooltip");
   end Test_Info_Pane_Section_Tooltips;
