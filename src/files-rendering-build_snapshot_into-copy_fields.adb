separate (Files.Rendering.Build_Snapshot_Into)
   --  The header, status and pane fields: copied straight from the model
   --  and the settings.
   procedure Copy_Fields is
   begin
      Snapshot.Current_Path := To_Unbounded_String (Files.Model.Current_Path (Model));
      Snapshot.Current_Path_Is_Favorite :=
        Files.Settings.Is_Favorite (Settings, Files.Model.Current_Path (Model));
      Snapshot.In_Recent_View := Files.Model.In_Recent_View (Model);
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
         Space : constant Files.Model.Volume_Space := Files.Model.Status_Samples.Volume_Space_Of (Model);
      begin
         Snapshot.Free_Space_Known := Space.Known;
         Snapshot.Free_Space_Bytes := Space.Free_Bytes;
         Snapshot.Total_Space_Bytes := Space.Total_Bytes;
      end;
      Snapshot.Filter_Text := To_Unbounded_String (Files.Model.Filter_Text (Model));
      Snapshot.Search_Scope := Files.Model.Search_Scope_Of (Model);
      Snapshot.Search_Results_Active := Files.Model.Search_Results_Are_Active (Model);
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
      Snapshot.Text_Cursor_Position := Files.Model.Text_Cursor_Position (Model);
      Snapshot.Path_Input_Text := To_Unbounded_String (Files.Model.Path_Input_Text (Model));
      Snapshot.Path_Input_Valid := Files.Model.Path_Input_Is_Valid (Model);
      Snapshot.Path_Input_Error_Key := To_Unbounded_String (Files.Model.Path_Input_Error_Key (Model));
      Snapshot.Rename_Active := Files.Model.Rename.Is_Active (Model);
      Snapshot.Temporary_Item_Active := Files.Model.Temporary_Item_Is_Active (Model);
      Snapshot.Temporary_Item_Name := To_Unbounded_String (Files.Model.Temporary_Item_Name (Model));
      Snapshot.Info_Pane_Open := Files.Model.Info_Pane_Is_Open (Model);
      --  As the window layer draws it (Window_Overlay_Shown): not under the
      --  palette or a paste dialog, so the frame does not leave a hole for it.
      Snapshot.Settings_Pane_Open :=
        Files.Model.Window_Overlay_Shown (Model, Files.Model.Settings_Pane_Overlay);
      Snapshot.Icon_Theme := Settings.Icon_Theme;
      Snapshot.Info_Pane_Scroll_Lines := Files.Model.Info_Pane_Scroll_Lines (Model);
      Snapshot.Main_View_Scroll_Lines := Files.Model.Main_View_Scroll_Lines (Model);
      Snapshot.Context_Menu_Open := Files.Model.Context_Menu.Is_Open (Model);
      Snapshot.Context_Menu_Highlight := Files.Model.Context_Menu.Highlight (Model);
      Snapshot.Context_Menu_X := Files.Model.Context_Menu.X (Model);
      Snapshot.Context_Menu_Y := Files.Model.Context_Menu.Y (Model);
      Snapshot.Context_Menu_Target := Files.Model.Context_Menu.Target_Of (Model);
      Snapshot.Context_Menu_Item_Index := Files.Model.Context_Menu.Item_Index (Model);
      Snapshot.Paste_Conflict_Open := Files.Model.Pasting.Conflict_Is_Active (Model);
      Snapshot.Paste_Conflict_Name := To_Unbounded_String (Files.Model.Pasting.Conflict_Name (Model));
      Snapshot.Paste_Conflict_Apply_All := Files.Model.Pasting.Conflict_Apply_All (Model);
      declare
         use type Files.File_System.Drop_Import_Mode;
      begin
         Snapshot.Paste_Progress :=
           (Open            => Files.Model.Pasting.Execution_Is_Active (Model),
            Done            => Files.Model.Pasting.Execution_Done (Model),
            Total           => Files.Model.Pasting.Execution_Total (Model),
            Name            => To_Unbounded_String (Files.Model.Pasting.Execution_Current_Name (Model)),
            Moving          => Files.Model.Pasting.Execution_Mode (Model) = Files.File_System.Drop_Move,
            Operation_Label => To_Unbounded_String (Files.Model.Background_Operation_Label (Model)));
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
