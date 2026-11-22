with Files.Model.Recent;
with Files.Model.Info_Pane;
with Files.Model.Filtering;
with Files.Model.Creation;
with Files.Model.Jobs;
with Files.File_System_Types;
with Files.Settings.Path_References;
separate (Files.Rendering.Build_Snapshot_Into)
   --  The header, status and pane fields: copied straight from the model
   --  and the settings.
   procedure Copy_Fields is
   begin
      Snapshot.Current_Path := To_Unbounded_String (Files.Model.Current_Path (Model));
      Snapshot.Current_Path_Is_Favorite :=
        Files.Settings.Path_References.Is_Favorite (Settings, Files.Model.Current_Path (Model));
      Snapshot.In_Recent_View := Files.Model.Recent.In_Recent_View (Model);
      Snapshot.View_Mode := Files.Model.View_Mode_Of (Model);
      Snapshot.Sort_Field := Files.Model.Sort_Field_Of (Model);
      Snapshot.Sort_Ascending := Files.Model.Sort_Is_Ascending (Model);
      Snapshot.Sort_Menu_Open := Files.Model.Sort_Menu.Is_Open (Model);
      Snapshot.Sort_Menu_Highlight := Files.Model.Sort_Menu.Highlight (Model);
      Snapshot.Show_Extensions := Settings.Show_File_Extensions;
      Snapshot.Show_Used_Space := Settings.Show_Used_Space;
      Snapshot.Show_Space_Bar := Settings.Show_Space_Bar;
      Snapshot.Detail_Columns_Visible := Settings.Column_Visible;
      Snapshot.Detail_Column_Widths := Settings.Column_Widths;
      Snapshot.Detail_Column_Order := Settings.Column_Order;
      Snapshot.Group_By := Settings.Group_By;
      Snapshot.Item_Count := Files.Model.Item_Count (Model);
      Snapshot.Visible_Count := Files.Model.Visible_Count (Model);
      Snapshot.Hidden_Count := Files.Model.Hidden_Item_Count (Model);
      Snapshot.Selected_Count := Files.Model.Selection.Selected_Count (Model);
      Snapshot.Primary_Selected_Visible_Index :=
        Files.Model.Selection.Selected_Index (Model);
      declare
         --  Sampled by the window layer (see Volume_Space_Is_Current); unknown
         --  until it has been, so a bogus zero is never shown as a known value.
         Space : constant Files.File_System_Types.Volume_Space := Files.Model.Status_Samples.Volume_Space_Of (Model);
      begin
         Snapshot.Free_Space_Known := Space.Known;
         Snapshot.Free_Space_Bytes := Space.Free_Bytes;
         Snapshot.Total_Space_Bytes := Space.Total_Bytes;
      end;
      Snapshot.Filter_Text := To_Unbounded_String (Files.Model.Filtering.Filter_Text (Model));
      Snapshot.Search_Scope := Files.Model.Filtering.Search_Scope_Of (Model);
      Snapshot.Search_Results_Active := Files.Model.Filtering.Search_Results_Are_Active (Model);
      Snapshot.Last_Error_Key := To_Unbounded_String (Files.Model.Last_Error_Key (Model));
      Snapshot.Last_Error_Text :=
        (if Length (Snapshot.Last_Error_Key) = 0 then Null_Unbounded_String
         elsif Files.Model.Last_Error_Path (Model) = ""
         then To_Unbounded_String (Files.Localization.Text (To_String (Snapshot.Last_Error_Key)))
         else To_Unbounded_String
             (Files.Localization.Text
                (To_String (Snapshot.Last_Error_Key), "path", Files.Model.Last_Error_Path (Model))));
      if Length (Snapshot.Last_Error_Key) > 0 and then Files.Model.Last_Error_Notice (Model) /= "" then
         --  A second message the failure carries (Files.Model.Set_Error_Notice).
         Append (Snapshot.Last_Error_Text, " " & Files.Localization.Text (Files.Model.Last_Error_Notice (Model)));
      end if;
      Snapshot.Focus := Files.Model.Focus (Model);
      --  The caret of a field the frame draws (path, filter, ownership): the
      --  palette's and the settings pane's are drawn by their overlays, and
      --  a palette keystroke must not make the snapshot differ (it leaves
      --  the model's revision, Files.Model.Overlay_Revision).
      Snapshot.Text_Cursor_Position :=
        (if Snapshot.Focus in Files.UI_Types.Focus_Command_Palette | Files.UI_Types.Focus_Settings_Input
         then 0
         else Files.Model.Text_Cursor_Position (Model));
      Snapshot.Path_Input_Text := To_Unbounded_String (Files.Model.Path_Input_Text (Model));
      Snapshot.Path_Input_Valid := Files.Model.Path_Input_Is_Valid (Model);
      Snapshot.Path_Input_Error_Key := To_Unbounded_String (Files.Model.Path_Input_Error_Key (Model));
      Snapshot.Rename_Active := Files.Model.Rename.Is_Active (Model);
      Snapshot.Temporary_Item_Active := Files.Model.Creation.Temporary_Item_Is_Active (Model);
      Snapshot.Temporary_Item_Name := To_Unbounded_String (Files.Model.Creation.Temporary_Item_Name (Model));
      Snapshot.Info_Pane_Open := Files.Model.Info_Pane.Info_Pane_Is_Open (Model);
      --  As the window layer draws it (Window_Overlay_Shown): not under the
      --  palette or a paste dialog, so the frame does not leave a hole for it.
      Snapshot.Settings_Pane_Open :=
        Files.Model.Window_Overlay_Shown (Model, Files.UI_Types.Settings_Pane_Overlay);
      Snapshot.Icon_Theme := Settings.Icon_Theme;
      Snapshot.Info_Pane_Scroll_Lines := Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model);
      Snapshot.Main_View_Scroll_Lines := Files.Model.Main_View_Scroll_Lines (Model);
      Snapshot.Context_Menu_Open := Files.Model.Context_Menu.Is_Open (Model);
      Snapshot.Context_Menu_Highlight := Files.Model.Context_Menu.Highlight (Model);
      Snapshot.Context_Menu_X := Files.Model.Context_Menu.X (Model);
      Snapshot.Context_Menu_Y := Files.Model.Context_Menu.Y (Model);
      Snapshot.Context_Menu_Target := Files.Model.Context_Menu.Target_Of (Model);
      Snapshot.Paste_Conflict_Open := Files.Model.Pasting.Conflict_Is_Active (Model);
      Snapshot.Paste_Conflict_Name := To_Unbounded_String (Files.Model.Pasting.Conflict_Name (Model));
      Snapshot.Paste_Conflict_Apply_All := Files.Model.Pasting.Conflict_Apply_All (Model);
      declare
         Progress : constant Files.Model.Jobs.Foreground_Progress := Files.Model.Jobs.Foreground_Progress_Of (Model);
      begin
         Snapshot.Paste_Progress :=
           (Open            => Files.Model.Jobs.Foreground_Job_Is_Active (Model),
            Done            => Progress.Done,
            Total           => Progress.Total,
            Name            => Progress.Name,
            Moving          => Progress.Moving,
            Operation_Label => Progress.Label_Key);
      end;
      Snapshot.Theme_Palette :=
        (case Settings.Theme is
            when Files.Settings.Theme_Dark          => Guikit.Draw.Theme_Dark,
            when Files.Settings.Theme_Light         => Guikit.Draw.Theme_Light,
            when Files.Settings.Theme_High_Contrast => Guikit.Draw.Theme_High_Contrast);
      --  High contrast rings focus in the selection colour, which stands out
      --  more than the border colour the other themes use.
      Snapshot.Theme_Focus_Ring :=
        (if Files.Settings."=" (Settings.Theme, Files.Settings.Theme_High_Contrast) then Guikit.Draw.Selection_Color
         else Guikit.Draw.Border_Color);
   end Copy_Fields;
