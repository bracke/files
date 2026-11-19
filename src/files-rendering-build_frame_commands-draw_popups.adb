separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Popups is
      --  The chrome of a centered, titled modal panel (Quick Look, the label
      --  picker): the modal chrome on the pane colour, the accent band along
      --  its top, its title and close button.
      procedure Draw_Titled_Panel
        (X, Y, W, H                : Natural;
         Title_X, Title_Y, Title_W : Natural;
         Close_Button              : Close_Button_Layout;
         Title                     : UString;
         Name                      : UString;
         Description               : UString := Null_Unbounded_String)
      is
         Accent_H : constant Natural := Natural'Min (Guikit.Layout.Scaled (3, Line_Height), H);
      begin
         Draw_Modal_Chrome (X, Y, W, H, Pane_Color, Role_Dialog, Name, Description);
         Add_Overlay_Rect (X, Y, W, Accent_H, Selection_Color);
         Add_Overlay_Text (Title_X, Title_Y, Title_W, Line_Height, Title, Fit => True);
         Draw_Close_Button (Close_Button, Overlay => True);
      end Draw_Titled_Panel;

      --  The Quick Look panel, drawn from its own part of the snapshot.
      procedure Draw_Quick_Look (Look : Quick_Look_Snapshot) is separate;

      --  The label picker's swatch panel.
      procedure Draw_Label_Picker is separate;

      --  The sort-field menu.
      procedure Draw_Sort_Menu is separate;
   begin
      if Snapshot.Quick_Look.Open then
         Draw_Quick_Look (Snapshot.Quick_Look);
      end if;
      if Snapshot.Label_Picker_Open then
         Draw_Label_Picker;
      end if;
      if Snapshot.Sort_Menu_Open then
         Draw_Sort_Menu;
      end if;
   end Draw_Popups;
