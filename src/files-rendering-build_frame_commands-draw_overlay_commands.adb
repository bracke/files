with Guikit.List_Panel;

separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Overlay_Commands is
      --  A dialog's two-line message in its message box: First in the text
      --  colour on the first line, Second in Second_Color on the line below,
      --  each drawn only where the box is tall enough to show it.
      procedure Draw_Dialog_Message
        (X, Y, Box_W, Box_H : Natural;
         First              : UString;
         Second             : UString;
         Second_Color       : Render_Color) is
      begin
         if Box_H > 0 then
            Add_Overlay_Text (X, Y, Box_W, Natural'Min (Line_Height, Box_H), First, Text_Color, Fit => True);
         end if;
         if Box_H > Line_Height then
            Add_Overlay_Text
              (X, Guikit.Layout.Saturating_Add (Y, Line_Height), Box_W, Natural'Min (Line_Height, Box_H - Line_Height),
               Second, Second_Color, Fit => True);
         end if;
      end Draw_Dialog_Message;

      procedure Draw_Root_Selector is separate;
      procedure Draw_Context_Menu is separate;
      procedure Draw_Paste_Conflict is separate;
      procedure Draw_Paste_Progress (Progress : Paste_Progress_Snapshot) is separate;
   begin
      if Snapshot.Root_Selector_Open then
         Draw_Root_Selector;
      end if;

      if Snapshot.Context_Menu_Open then
         Draw_Context_Menu;
      end if;

      if Snapshot.Paste_Conflict_Open then
         Draw_Paste_Conflict;
      end if;

      if Snapshot.Paste_Progress.Open then
         Draw_Paste_Progress (Snapshot.Paste_Progress);
      end if;
   end Draw_Overlay_Commands;
