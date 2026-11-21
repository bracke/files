separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Close_Button
     (Btn     : Close_Button_Layout;
      Overlay : Boolean)
   is
   begin
      if not Btn.Visible then
         return;
      end if;

      declare
         Hovered    : constant Boolean :=
           Is_Hovered (Btn.X, Btn.Y, Btn.Width, Btn.Height);
         Pressed    : constant Boolean := Is_Pressed (Btn.X, Btn.Y, Btn.Width, Btn.Height);
         Fill_Color : constant Render_Color :=
           (if Pressed then Pressed_Color
            elsif Hovered then Hover_Color
            elsif Overlay then Overlay_Color
            else Pane_Color);
         --  Center the glyph cell within the square button.
         Glyph_W    : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
         Glyph_X    : constant Natural :=
           (if Btn.Width > Glyph_W
            then Guikit.Layout.Saturating_Add (Btn.X, (Btn.Width - Glyph_W) / 2)
            else Btn.X);
         Glyph_Y    : constant Natural :=
           (if Btn.Height > Line_Height
            then Guikit.Layout.Saturating_Add (Btn.Y, (Btn.Height - Line_Height) / 2)
            else Btn.Y);

         --  The button into one layer's rectangles and text.
         procedure Draw_Into
           (Rectangles : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
            Text       : in out Guikit.Draw.Text_Command_Vectors.Vector) is
         begin
            Guikit.Widgets.Draw_Close_Button
              (Rectangles    => Rectangles,
               Text          => Text,
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
               Show_Glyph    => True);
         end Draw_Into;
      begin
         if Overlay then
            Draw_Into (Result.Overlay_Rectangles, Result.Overlay_Text);
         else
            Draw_Into (Result.Rectangles, Result.Text);
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
