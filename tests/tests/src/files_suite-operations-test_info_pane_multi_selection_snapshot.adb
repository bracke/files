separate (Files_Suite.Operations)
   procedure Test_Info_Pane_Multi_Selection_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;
   begin
      Reset_Root;
      Write_Info_Metadata_Fixtures;
      Write_File (Join (Root, "more.txt"), "efgh");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Filter (Model, ".txt");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Files_Suite.Support.Assert_Equal
        (Natural (Snapshot.Selected_Info.Length),
         2,
         "info snapshot includes all selected items");
      Files_Suite.Support.Assert_Equal
        (To_String (Snapshot.Selected_Info.Element (1).Name),
         "meta.txt",
         "multi-selection info preserves first selected item order");
      Files_Suite.Support.Assert_Equal
        (To_String (Snapshot.Selected_Info.Element (2).Name),
         "more.txt",
         "multi-selection info preserves second selected item order");
      Files_Suite.Support.Assert_Equal
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Detail),
         Files.Localization.Text ("info.kind.text"),
         "multi-selection info localizes first filetype detail");
      Files_Suite.Support.Assert_Equal
        (To_String (Snapshot.Selected_Info.Element (2).Filetype_Detail),
         Files.Localization.Text ("info.kind.text"),
         "multi-selection info localizes second filetype detail");
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
      declare
         Layout       : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
         Info_Layout  : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height => 20);
         --  A multi-item selection draws a COALESCED, field-major layout: each
         --  section label appears once and each value row is postfixed with its
         --  item name, so there is no dedicated Name section.
         Name_Label       : constant String := Files.Localization.Text ("info.name");
         Name_Label_Count : Natural := 0;
         Meta_Postfixed   : Boolean := False;
         More_Postfixed   : Boolean := False;

         function Ends_With (Text : Unbounded_String; Suffix : String) return Boolean is
         begin
            return Length (Text) >= Suffix'Length
              and then Slice (Text, Length (Text) - Suffix'Length + 1, Length (Text)) = Suffix;
         end Ends_With;
      begin
         for Text of Frame.Text loop
            if Text.X >= Info_Layout.X then
               if To_String (Text.Text) = Name_Label then
                  Name_Label_Count := Name_Label_Count + 1;
               elsif Ends_With (Text.Text, " (meta.txt)") then
                  Meta_Postfixed := True;
               elsif Ends_With (Text.Text, " (more.txt)") then
                  More_Postfixed := True;
               end if;
            end if;
         end loop;

         Files_Suite.Support.Assert_Equal

           (Name_Label_Count,

            0,

            "coalesced info pane has no dedicated Name section");
         Assert
           (Meta_Postfixed and then More_Postfixed,
            "each selected item's rows are postfixed with its own name");
      end;
   end Test_Info_Pane_Multi_Selection_Snapshot;
