separate (Files.Rendering.Build_Frame_Commands.Draw_Overlay_Commands)
   --  The paste-progress panel.
   procedure Draw_Paste_Progress is
   begin
      declare
         Panel  : constant Paste_Progress_Layout :=
           Calculate_Paste_Progress_Layout (Layout, Line_Height);
         Verb_Key : constant String :=
           (if Length (Snapshot.Paste_Progress_Operation_Label) > 0
            then To_String (Snapshot.Paste_Progress_Operation_Label)
            elsif Snapshot.Paste_Progress_Moving then "dialog.paste_progress.moving"
            else "dialog.paste_progress.copying");
         Count_Line : constant UString :=
           (Localized (Verb_Key)
           & To_Unbounded_String (" ")
           & To_Unbounded_String (Grouped_Integer_Text (Long_Long_Integer (Snapshot.Paste_Progress_Done)))
           & To_Unbounded_String (" ")
           & Localized ("dialog.paste_progress.of")
           & To_Unbounded_String (" ")
           & To_Unbounded_String (Grouped_Integer_Text (Long_Long_Integer (Snapshot.Paste_Progress_Total))));
         Cancel_Hovered : constant Boolean :=
           Has_Hover
           and then Contains_Point
                      (Panel.Cancel_X, Panel.Cancel_Y, Panel.Cancel_Width, Panel.Cancel_Height,
                       Hover_X, Hover_Y);
         Cancel_Pressed : constant Boolean :=
           Is_Pressed (Panel.Cancel_X, Panel.Cancel_Y, Panel.Cancel_Width, Panel.Cancel_Height);
      begin
         --  Progress owns pointer, keyboard, and text input until completion
         --  or cancellation.  Match that blocking behavior visually and in
         --  the accessibility tree instead of leaving inactive controls
         --  apparently available behind the panel.
         Result.Accessibility.Clear;
         Add_Overlay_Rect (0, 0, Width, Height, Modal_Backdrop_Color);
         Add_Overlay_Drop_Shadow (Panel.X, Panel.Y, Panel.Width, Panel.Height);

         --  Blocking progress panel body and border.
         Add_Overlay_Rect (Panel.X, Panel.Y, Panel.Width, Panel.Height, Overlay_Color);
         Add_Overlay_Border (Panel.X, Panel.Y, Panel.Width, Panel.Height, Border_Color);
         Add_Accessibility_Node
           (Role_Dialog, Panel.X, Panel.Y, Panel.Width, Panel.Height,
            (if Length (Snapshot.Paste_Progress_Operation_Label) > 0 then Localized (Verb_Key)
             else Localized ("dialog.paste_progress.title")));

         --  "Copying/Moving N of M" plus the current item name.
         if Panel.Message_Height > 0 then
            Add_Overlay_Text
              (Panel.Message_X, Panel.Message_Y,
               Panel.Message_Width, Natural'Min (Line_Height, Panel.Message_Height),
               Count_Line, Text_Color, Fit => True);
         end if;
         if Panel.Message_Height > Line_Height then
            Add_Overlay_Text
              (Panel.Message_X, Saturating_Add (Panel.Message_Y, Line_Height),
               Panel.Message_Width,
               Natural'Min (Line_Height, Panel.Message_Height - Line_Height),
               Snapshot.Paste_Progress_Name, Muted_Text_Color, Fit => True);
         end if;

         --  Progress bar: track + fill proportional to Done/Total, top border.
         Guikit.Widgets.Draw_Meter
           (Result.Overlay_Rectangles, Layout.Width, Layout.Height,
            Panel.Bar_X, Panel.Bar_Y, Panel.Bar_Width, Panel.Bar_Height,
            Long_Long_Integer (Snapshot.Paste_Progress_Done),
            Long_Long_Integer (Snapshot.Paste_Progress_Total),
            Hover_Color, Selection_Color);
         Add_Overlay_Rect (Panel.Bar_X, Panel.Bar_Y, Panel.Bar_Width, 1, Border_Color);

         --  Cancel button.
         Guikit.Widgets.Draw_Button
           (Rectangles      => Result.Overlay_Rectangles,
            Text            => Result.Overlay_Text,
            Clip_Width      => Layout.Width,
            Clip_Height     => Layout.Height,
            X               => Panel.Cancel_X,
            Y               => Panel.Cancel_Y,
            Width           => Panel.Cancel_Width,
            Height          => Panel.Cancel_Height,
            Fill_Color      =>
              (if Cancel_Pressed then Pressed_Color
               elsif Cancel_Hovered then Hover_Color else Overlay_Color),
            Border_Color    => Border_Color,
            Padding         => Guikit.Layout.Input_Field_Padding,
            Label_Text      => Localized ("dialog.paste_progress.button.cancel"),
            Label_Truncated => False,
            Label_Height    => Line_Height,
            Label_Color     => Text_Color);
         Add_Accessibility_Node
           (Role_Button, Panel.Cancel_X, Panel.Cancel_Y, Panel.Cancel_Width, Panel.Cancel_Height,
            Localized ("dialog.paste_progress.button.cancel"));
         Add_Conflict_Hit
           (Conflict_Hit_Progress_Cancel,
            Panel.Cancel_X, Panel.Cancel_Y,
            Panel.Cancel_Width, Panel.Cancel_Height);
      end;
   end Draw_Paste_Progress;
