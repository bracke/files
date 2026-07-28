separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Close_Button
     (Panel_X : Natural;
      Panel_Y : Natural;
      Panel_W : Natural;
      Panel_H : Natural;
      Overlay : Boolean)
   is
      Btn : constant Close_Button_Layout :=
        Panel_Close_Button (Panel_X, Panel_Y, Panel_W, Panel_H, Line_Height);
   begin
      if not Btn.Visible then
         return;
      end if;

      declare
         Hovered    : constant Boolean :=
           Has_Hover and then Contains_Point (Btn.X, Btn.Y, Btn.Width, Btn.Height, Hover_X, Hover_Y);
         Pressed    : constant Boolean := Is_Pressed (Btn.X, Btn.Y, Btn.Width, Btn.Height);
         Fill_Color : constant Render_Color :=
           (if Pressed then Pressed_Color
            elsif Hovered then Hover_Color
            elsif Overlay then Overlay_Color
            else Pane_Color);
         --  Center the glyph cell within the square button.
         Glyph_W    : constant Positive := Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
         Glyph_X    : constant Natural :=
           (if Btn.Width > Glyph_W
            then Saturating_Add (Btn.X, (Btn.Width - Glyph_W) / 2)
            else Btn.X);
         Glyph_Y    : constant Natural :=
           (if Btn.Height > Line_Height
            then Saturating_Add (Btn.Y, (Btn.Height - Line_Height) / 2)
            else Btn.Y);
         --  Base-layer glyph text is suppressed when covered by the settings
         --  pane or command palette; overlay glyphs are never hidden.
         Show_Glyph : constant Boolean :=
           Overlay
           or else not (Hidden_By_Settings_Pane (Glyph_X, Glyph_Y, Glyph_W, Line_Height)
                        or else Hidden_By_Command_Palette (Glyph_X, Glyph_Y, Glyph_W, Line_Height));
      begin
         if Overlay then
            Guikit.Widgets.Draw_Close_Button
              (Rectangles    => Result.Overlay_Rectangles,
               Text          => Result.Overlay_Text,
               Clip_Width    => Layout.Width,
               Clip_Height   => Layout.Height,
               Button_X      => Btn.X,
               Button_Y      => Btn.Y,
               Button_Width  => Btn.Width,
               Button_Height => Btn.Height,
               Fill_Color    => Fill_Color,
               Border_Color  => Border_Color,
               Glyph_X       => Glyph_X,
               Glyph_Y       => Glyph_Y,
               Glyph_Width   => Glyph_W,
               Glyph_Height  => Line_Height,
               Glyph         => To_Unbounded_String (Close_Glyph_Text),
               Glyph_Color   => Text_Color,
               Show_Glyph    => Show_Glyph);
         else
            Guikit.Widgets.Draw_Close_Button
              (Rectangles    => Result.Rectangles,
               Text          => Result.Text,
               Clip_Width    => Layout.Width,
               Clip_Height   => Layout.Height,
               Button_X      => Btn.X,
               Button_Y      => Btn.Y,
               Button_Width  => Btn.Width,
               Button_Height => Btn.Height,
               Fill_Color    => Fill_Color,
               Border_Color  => Border_Color,
               Glyph_X       => Glyph_X,
               Glyph_Y       => Glyph_Y,
               Glyph_Width   => Glyph_W,
               Glyph_Height  => Line_Height,
               Glyph         => To_Unbounded_String (Close_Glyph_Text),
               Glyph_Color   => Text_Color,
               Show_Glyph    => Show_Glyph);
         end if;

         Add_Accessibility_Node
           (Role_Button,
            Btn.X,
            Btn.Y,
            Btn.Width,
            Btn.Height,
            Localized ("command.action.close"));
      end;
   end Draw_Close_Button;
