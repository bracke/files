separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Main_View is
      procedure Draw_Details_Header is separate;
      procedure Draw_Item (Index : Positive) is separate;
      procedure Draw_Column_Separators is separate;
      procedure Draw_Drag_Preview is separate;
      procedure Draw_Empty_State is separate;
   begin
      if Snapshot.View_Mode = Files.Types.Details then
         Draw_Details_Header;
      end if;

      for Index in 1 .. Natural (Items.Length) loop
         Draw_Item (Index);
      end loop;

      if Snapshot.View_Mode = Files.Types.Details and then not Items.Is_Empty then
         Draw_Column_Separators;
      end if;

      --  Rubber-band (marquee) selection rectangle: a translucent fill plus a
      --  solid selection-colored border over the grid while an empty-space drag
      --  is in progress. The items it touches are already drawn selected via the
      --  selection set, so this only shows the drag region itself.
      if Marquee_Active
        and then Marquee_W > 0
        and then Marquee_H > 0
        and then Width > 0
        and then Height > 0
      then
         Guikit.Widgets.Draw_Marquee
           (Rectangles   => Result.Rectangles,
            Clip_Width   => Layout.Width,
            Clip_Height  => Layout.Height,
            X            => Marquee_X,
            Y            => Marquee_Y,
            Width        => Marquee_W,
            Height       => Marquee_H,
            Fill_Color   => Marquee_Color,
            Border_Color => Selection_Color);
      end if;

      if Has_Drag
        and then Drag_Item_Index /= 0
        and then not Snapshot.Items.Is_Empty
        and then Width > 0
        and then Height > 0
      then
         Draw_Drag_Preview;
      end if;

      if Empty_State_Key /= "" and then Layout.Main_Width > 0 and then Layout.Main_Height > 0 then
         Draw_Empty_State;
      end if;

      if Main_View.Scrollbar_Visible then
         Add_Scrollbar
           (Main_View.Scrollbar_X,
            Main_View.Scrollbar_Y,
            Main_View.Scrollbar_Width,
            Main_View.Scrollbar_Track_Height,
            Main_View.Scrollbar_Thumb_Y,
            Main_View.Scrollbar_Height);
      end if;
   end Draw_Main_View;
