separate (Files.Rendering.Build_Frame_Commands.Draw_Main_View)
   --  The empty-folder (or no-match) explanation, centred in the main view.
   procedure Draw_Empty_State is
      Panel_W : constant Natural :=
        Natural'Min
          (Natural'Max (Guikit.Layout.Scaled (240, Line_Height), Layout.Main_Width / 2), Layout.Main_Width);
      Panel_H : constant Natural := Natural'Min (Saturating_Multiply (Line_Height, 3), Layout.Main_Height);
      Panel_X : constant Natural :=
        Guikit.Layout.Saturating_Add
          (Layout.Main_X,
           Centered (Layout.Main_Width, Panel_W));
      Panel_Y : constant Natural :=
        Guikit.Layout.Saturating_Add
          (Layout.Main_Y,
           Centered (Layout.Main_Height, Panel_H));
      Text_H : constant Natural := Natural'Min (Line_Height, Panel_H);
      Text_Y : constant Natural :=
        Guikit.Layout.Saturating_Add (Panel_Y, Centered (Panel_H, Text_H));
      Side_Pad : constant Natural := Natural'Min (Guikit.Layout.Scaled (8, Line_Height), Panel_W / 4);
      Inner_X  : constant Natural := Guikit.Layout.Saturating_Add (Panel_X, Side_Pad);
      Inner_W  : constant Natural :=
        (if Panel_W > Saturating_Multiply (Side_Pad, 2)
         then Panel_W - Saturating_Multiply (Side_Pad, 2)
         else 0);
      Desired_Icon : constant Natural := Natural'Min (Line_Height, Panel_H);
      --  Text is the useful empty-state explanation. Drop the decorative
      --  icon when a compact panel cannot leave two text cells beside it.
      Icon_Size : constant Natural :=
        (if Inner_W > Guikit.Layout.Saturating_Add (Desired_Icon, Saturating_Multiply (Line_Height, 2))
         then Desired_Icon
         else 0);
      Icon_Gap : constant Natural :=
        (if Icon_Size > 0 then Natural'Min (Guikit.Layout.Scaled (8, Line_Height), Inner_W - Icon_Size) else 0);
      Icon_X : constant Natural := Inner_X;
      Text_X : constant Natural :=
        Guikit.Layout.Saturating_Add (Inner_X, Guikit.Layout.Saturating_Add (Icon_Size, Icon_Gap));
      Text_W : constant Natural :=
        (if Inner_W > Guikit.Layout.Saturating_Add (Icon_Size, Icon_Gap)
         then Inner_W - Icon_Size - Icon_Gap
         else 0);
   begin
      Add_Rect (Panel_X, Panel_Y, Panel_W, Panel_H, Pane_Color);
      Add_Border (Panel_X, Panel_Y, Panel_W, Panel_H, Border_Color);
      if Icon_Size > 0 then
         Add_Rect
           (Icon_X,
            Text_Y,
            Icon_Size,
            Natural'Min (Icon_Size, Text_H),
            Muted_Text_Color);
         if Icon_Size > 6 then
            Add_Rect
              (Guikit.Layout.Saturating_Add (Icon_X, Icon_Size / 4),
               Guikit.Layout.Saturating_Add (Text_Y, Icon_Size / 2),
               Icon_Size / 2,
               1,
               Pane_Color);
         end if;
      end if;
      Add_Text
        (Text_X,
         Text_Y,
         Text_W,
         Text_H,
         To_Unbounded_String (Files.Localization.Text (Empty_State_Key)),
         Muted_Text_Color,
         Fit => True);
   end Draw_Empty_State;
