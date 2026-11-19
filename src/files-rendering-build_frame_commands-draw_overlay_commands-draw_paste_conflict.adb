separate (Files.Rendering.Build_Frame_Commands.Draw_Overlay_Commands)
   --  The paste-conflict dialog.
   procedure Draw_Paste_Conflict is
   begin
      declare
         Dialog : constant Conflict_Dialog_Layout :=
           Calculate_Conflict_Dialog_Layout (Layout, Line_Height);

         procedure Draw_Button (Kind : Dialog_Hit_Kind; Button_X : Natural; Label_Key : String) is
            Hovered : constant Boolean :=
              Has_Hover
              and then Contains_Point
                         (Button_X, Dialog.Button_Y, Dialog.Button_Width, Dialog.Button_Height,
                          Hover_X, Hover_Y);
            Pressed : constant Boolean :=
              Is_Pressed (Button_X, Dialog.Button_Y, Dialog.Button_Width, Dialog.Button_Height);
         begin
            Guikit.Widgets.Draw_Button
              (Rectangles      => Result.Overlay_Rectangles,
               Text            => Result.Overlay_Text,
               Clip_Width      => Layout.Width,
               Clip_Height     => Layout.Height,
               X               => Button_X,
               Y               => Dialog.Button_Y,
               Width           => Dialog.Button_Width,
               Height          => Dialog.Button_Height,
               Fill_Color      =>
                 (if Pressed then Pressed_Color elsif Hovered then Hover_Color else Overlay_Color),
               Border_Color    => Border_Color,
               Padding         => Files.Rendering.Layouts.Field_Padding (Line_Height),
               Label_Text      => Localized (Label_Key),
               Label_Truncated => False,
               Label_Height    => Line_Height,
               Label_Color     => Text_Color);
            Add_Accessibility_Node
              (Role_Button, Button_X, Dialog.Button_Y, Dialog.Button_Width, Dialog.Button_Height,
               Localized (Label_Key));
            Add_Dialog_Hit
              (Kind, Button_X, Dialog.Button_Y,
               Dialog.Button_Width, Dialog.Button_Height);
         end Draw_Button;
      begin
         --  The conflict dialog owns input until it is resolved.  Hide the
         --  inactive view from assistive technology as well as dimming it;
         --  otherwise screen readers can still navigate controls that the
         --  click reducer deliberately makes unavailable.
         Draw_Modal_Chrome
           (Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height, Overlay_Color, Role_Dialog,
            Localized ("dialog.paste_conflict.title"),
            Backdrop => True);

         --  Conflicting name and the "already exists" line.
         Draw_Dialog_Message
           (Dialog.Message_X, Dialog.Message_Y, Dialog.Message_Width, Dialog.Message_Height,
            Snapshot.Paste_Conflict_Name, Localized ("dialog.paste_conflict.exists"), Text_Color);

         --  "Apply to all remaining" toggle row.
         declare
            Box_Size : constant Natural := Natural'Min (Line_Height, Dialog.Apply_Height);
            Text_Offset : constant Natural :=
              Guikit.Layout.Saturating_Add (Box_Size, Files.Rendering.Layouts.Field_Padding (Line_Height));
            Hovered  : constant Boolean :=
              Has_Hover
              and then Contains_Point
                         (Dialog.Apply_X, Dialog.Apply_Y, Dialog.Apply_Width, Dialog.Apply_Height,
                          Hover_X, Hover_Y);
         begin
            if Dialog.Apply_Width > 0 and then Dialog.Apply_Height > 0 then
               if Hovered then
                  Add_Overlay_Rect
                    (Dialog.Apply_X, Dialog.Apply_Y,
                     Dialog.Apply_Width, Dialog.Apply_Height, Hover_Color);
               end if;
               Add_Overlay_Rect
                 (Dialog.Apply_X, Dialog.Apply_Y, Box_Size, Box_Size, Border_Color);
               Add_Overlay_Rect
                 (Guikit.Layout.Saturating_Add (Dialog.Apply_X, 1), Guikit.Layout.Saturating_Add (Dialog.Apply_Y, 1),
                  (if Box_Size > 2 then Box_Size - 2 else 0),
                  (if Box_Size > 2 then Box_Size - 2 else 0),
                  (if Snapshot.Paste_Conflict_Apply_All
                   then Selection_Color else Overlay_Color));
               Add_Overlay_Text
                 (Guikit.Layout.Saturating_Add (Dialog.Apply_X, Text_Offset),
                  Dialog.Apply_Y,
                  (if Dialog.Apply_Width > Text_Offset
                   then Dialog.Apply_Width - Text_Offset
                   else 0),
                  Natural'Min (Line_Height, Dialog.Apply_Height),
                  Localized ("dialog.paste_conflict.apply_to_all"),
                  Text_Color,
                  Fit => True);
               Add_Accessibility_Node
                 (Role_Button,
                  Dialog.Apply_X, Dialog.Apply_Y,
                  Dialog.Apply_Width, Dialog.Apply_Height,
                  Localized ("dialog.paste_conflict.apply_to_all"),
                  Selected => Snapshot.Paste_Conflict_Apply_All);
               Add_Dialog_Hit
                 (Dialog_Hit_Apply_All,
                  Dialog.Apply_X, Dialog.Apply_Y,
                  Dialog.Apply_Width, Dialog.Apply_Height);
            end if;
         end;

         Draw_Button (Dialog_Hit_Replace, Dialog.Replace_X, "dialog.paste_conflict.button.replace");
         Draw_Button (Dialog_Hit_Skip, Dialog.Skip_X, "dialog.paste_conflict.button.skip");
         Draw_Button (Dialog_Hit_Rename, Dialog.Rename_X, "dialog.paste_conflict.button.rename");
         Draw_Button (Dialog_Hit_Cancel, Dialog.Cancel_X, "dialog.paste_conflict.button.cancel");

         --  Close button in the panel corner cancels the whole paste; it is
         --  recorded with the other controls, so one mechanism hit-tests them.
         Draw_Close_Button (Dialog.Close_Button, Overlay => True);
         if Dialog.Close_Button.Visible then
            Add_Dialog_Hit
              (Dialog_Hit_Conflict_Close,
               Dialog.Close_Button.X, Dialog.Close_Button.Y,
               Dialog.Close_Button.Width, Dialog.Close_Button.Height);
         end if;
      end;
   end Draw_Paste_Conflict;
