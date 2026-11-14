separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Info_Pane is
      procedure Draw_Info_Contents is separate;
   begin
      if Snapshot.Info_Pane_Open then
         Add_Rect
           (Info_Pane.X,
            Info_Pane.Y,
            Info_Pane.Width,
            Natural'Min (Guikit.Layout.Scaled (2, Line_Height), Info_Pane.Height),
            Border_Color);
         Add_Accessibility_Node
           (Role_Pane,
            Info_Pane.X,
            Info_Pane.Y,
            Info_Pane.Width,
            Info_Pane.Height,
            Localized ("accessibility.info_pane"),
            (if Snapshot.Selected_Info.Is_Empty
             then Localized ("error.selection.empty")
             else Null_Unbounded_String));
         Draw_Info_Contents;

         if Info_Pane.Scrollbar_Visible then
            Add_Scrollbar
              (Info_Pane.Scrollbar_X,
               Info_Pane.Scrollbar_Y,
               Info_Pane.Scrollbar_Width,
               Info_Pane.Scrollbar_Track_Height,
               Info_Pane.Scrollbar_Thumb_Y,
               Info_Pane.Scrollbar_Height);
         end if;
         --  Keep the close button clear of the scrollbar column on the right.
         Draw_Close_Button
           (Info_Pane.X,
            Info_Pane.Y,
            (if Info_Pane.Scrollbar_Visible and then Info_Pane.Width > Info_Pane.Scrollbar_Width
             then Info_Pane.Width - Info_Pane.Scrollbar_Width
             else Info_Pane.Width),
            Info_Pane.Height,
            Overlay => False);
      end if;
   end Draw_Info_Pane;
