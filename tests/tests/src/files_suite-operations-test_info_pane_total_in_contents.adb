separate (Files_Suite.Operations)
   procedure Test_Info_Pane_Total_In_Contents (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "fa"));
      Ada.Directories.Create_Path (Join (Root, "fb"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_All_Visible (Model);
      Files.Model.Toggle_Info_Pane (Model);
      Assert (Files.Model.Selected_Count (Model) = 2, "two folders are selected");

      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 800, Height => 1200, Line_Height => 20);

      declare
         Info_X         : constant Natural := Frame.Layout.Main_Width;
         Contents_Label : constant String := Files.Localization.Text ("info.folder_size");
         Filetype_Label : constant String := Files.Localization.Text ("info.filetype");
         Total_Prefix   : constant String := Files.Localization.Text ("info.contents.total") & ":";
         Contents_Y     : Integer := -1;
         Filetype_Y     : Integer := -1;
         Total_Y        : Integer := -1;
      begin
         for Text of Frame.Text loop
            if Text.X >= Info_X then
               declare
                  V : constant String := To_String (Text.Text);
               begin
                  if V = Contents_Label then
                     Contents_Y := Integer (Text.Y);
                  elsif V = Filetype_Label then
                     Filetype_Y := Integer (Text.Y);
                  elsif Ada.Strings.Fixed.Index (V, Total_Prefix) = 1 then
                     Total_Y := Integer (Text.Y);
                  end if;
               end;
            end if;
         end loop;

         Assert (Total_Y >= 0, "the combined selection total is rendered in the info pane");
         Assert (Contents_Y >= 0, "the Contents section is present for a folder selection");
         Assert (Total_Y > Contents_Y, "the total is below the Contents label (part of that section)");
         Assert (Filetype_Y >= 0 and then Total_Y > Filetype_Y,
                 "the total is no longer a header above the sections");
      end;
   end Test_Info_Pane_Total_In_Contents;
