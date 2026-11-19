with Files.Rendering.Layouts;
with Guikit.Layout;
separate (Files_Suite.Rendering)
   --  An open overlay takes the pointer from the window under it, but for
   --  the one button whose click still reaches it and closes it: the
   --  toolbar's drive button under the root selector, the bottom bar's sort
   --  button under the sort menu. That button is drawn hovered and pressed
   --  as the pointer has it (the drive button is the toolbar's first,
   --  Files.Rendering.Layouts.Toolbar_Button_Commands); its neighbours, and
   --  the same button under another overlay, are not.
   procedure Test_Overlay_Toggle_Button_Takes_Pointer (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant := 900;
      Height : constant := 480;
      Base   : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Frame  : constant Files.Rendering.Layouts.Frame_Layout :=
        Files.Rendering.Layouts.Calculate_Frame_Layout (Base, Width, Height, 20);
      Toolbar : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Width, 20);
      Button_Y : constant Natural := Guikit.Layout.Toolbar_Input_Y (20) + Guikit.Layout.Toolbar_Input_Height (20) / 2;

      --  The centre of toolbar button Index.
      function Button_X (Index : Natural) return Natural is
        (Guikit.Layout.Toolbar_Left_Button_X (Toolbar, Index)
         + Guikit.Layout.Toolbar_Left_Button_Width (Toolbar, Index) / 2);

      --  Whether a rectangle in Color is drawn under (X, Y) in the band
      --  Top .. Bottom, with the pointer over (X, Y) and, when Press, held
      --  down there.
      function Drawn
        (Snap   : View_Snapshot;
         X, Y   : Natural;
         Press  : Boolean;
         Color  : Guikit.Draw.Render_Color;
         Top    : Natural;
         Bottom : Natural)
         return Boolean
      is
         Commands : constant Frame_Commands :=
           Build_Frame_Commands
             (Snap, Width, Height, 20,
              Pointer =>
                (Hover_X => X, Hover_Y => Y, Has_Hover => True,
                 Pressed => Press, Press_X => X, Press_Y => Y, others => <>));
      begin
         for Rect of Commands.Rectangles loop
            if Rect.Color = Color
              and then Rect.Y >= Top and then Rect.Y < Bottom
              and then X >= Rect.X and then X < Rect.X + Rect.Width
            then
               return True;
            end if;
         end loop;
         return False;
      end Drawn;

      Root_Open    : View_Snapshot := Base;
      Palette_Open : View_Snapshot := Base;
      Sort_Open    : View_Snapshot := Base;
      Toolbar_Low  : constant Natural := Frame.Layout.Toolbar_Height;
      Sort_X       : constant Natural := Frame.Bottom.Sort_Button_X + Frame.Bottom.Sort_Button_Width / 2;
      Sort_Y       : constant Natural := Frame.Bottom_Y + Frame.Layout.Bottom_Bar_Height / 2;
   begin
      Root_Open.Root_Selector_Open := True;
      Palette_Open.Command_Palette_Open := True;
      Sort_Open.Sort_Menu_Open := True;

      Assert
        (Drawn (Root_Open, Button_X (0), Button_Y, False, Guikit.Draw.Hover_Color, 0, Toolbar_Low),
         "the drive button is hovered under the root selector it toggles");
      Assert
        (Drawn (Root_Open, Button_X (0), Button_Y, True, Guikit.Draw.Pressed_Color, 0, Toolbar_Low),
         "and pressed");
      Assert
        (not Drawn (Root_Open, Button_X (1), Button_Y, False, Guikit.Draw.Hover_Color, 0, Toolbar_Low)
         and then not Drawn (Root_Open, Button_X (1), Button_Y, True, Guikit.Draw.Pressed_Color, 0, Toolbar_Low),
         "its neighbour, which the selector's click does not reach, is neither");
      Assert
        (not Drawn (Palette_Open, Button_X (0), Button_Y, True, Guikit.Draw.Pressed_Color, 0, Toolbar_Low),
         "nor is the drive button under the palette");

      Assert (Frame.Bottom.Sort_Button_Width > 0, "the sort button is drawn at this width");
      Assert
        (Drawn (Sort_Open, Sort_X, Sort_Y, True, Guikit.Draw.Pressed_Color, Frame.Bottom_Y, Height),
         "the sort button is pressed under the sort menu it toggles");
      Assert
        (Drawn (Sort_Open, Sort_X, Sort_Y, False, Guikit.Draw.Selection_Color, Frame.Bottom_Y, Height),
         "and drawn selected while it is only hovered");
      Assert
        (not Drawn (Root_Open, Sort_X, Sort_Y, True, Guikit.Draw.Pressed_Color, Frame.Bottom_Y, Height),
         "it is not pressed under the root selector");
   end Test_Overlay_Toggle_Button_Takes_Pointer;
