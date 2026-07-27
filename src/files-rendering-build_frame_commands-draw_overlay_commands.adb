separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Overlay_Commands is
   begin
      if Snapshot.Root_Selector_Open then
         if Root_Selector.Width > 0 and then Root_Selector.Height > 0 then
            Add_Overlay_Rect
              (Saturating_Add (Root_Selector.X, 3),
               Saturating_Add (Root_Selector.Y, Root_Selector.Height),
               Root_Selector.Width,
               3,
               Pane_Color);
            Add_Overlay_Rect
              (Saturating_Add (Root_Selector.X, Root_Selector.Width),
               Saturating_Add (Root_Selector.Y, 3),
               3,
               Root_Selector.Height,
               Pane_Color);
            Add_Overlay_Rect
              (Root_Selector.X,
               Root_Selector.Y,
               Root_Selector.Width,
               Root_Selector.Height,
               Overlay_Color);
            Add_Overlay_Border
              (Root_Selector.X, Root_Selector.Y,
               Root_Selector.Width, Root_Selector.Height, Border_Color);
         end if;
         Add_Accessibility_Node
           (Role_List,
            Root_Selector.X,
            Root_Selector.Y,
            Root_Selector.Width,
            Root_Selector.Height,
            Localized ("accessibility.root_selector"));

         for Index in 1 .. Natural (Root_Rows.Length) loop
            declare
               Row       : constant Root_Path_Layout := Root_Rows.Element (Positive (Index));
               Toolbar_Icon_Size : constant Natural :=
                 Saturating_Add (Line_Height, Saturating_Multiply (Guikit.Layout.Input_Field_Padding, 2));
               Row_Pad    : constant Natural := Natural'Min (Root_Selector_Padding, Row.Height);
               Inner_H    : constant Natural :=
                 (if Row.Height > Saturating_Multiply (Row_Pad, 2)
                  then Row.Height - Saturating_Multiply (Row_Pad, 2)
                  else Row.Height);
               Glyph_Size : constant Natural := Natural'Min (Toolbar_Icon_Size, Inner_H);
               Glyph_X    : constant Natural := Saturating_Add (Row.X, Row_Pad);
               Glyph_Y    : constant Natural :=
                  (if Row.Height > Glyph_Size
                  then Saturating_Add (Row.Y, (Row.Height - Glyph_Size) / 2)
                  else Row.Y);
               Text_X     : constant Natural :=
                 Saturating_Add (Glyph_X, Saturating_Add (Glyph_Size, Root_Selector_Padding));
               Text_H     : constant Natural :=
                 Natural'Min (Line_Height, Inner_H);
               Text_Y     : constant Natural :=
                 (if Row.Height > Text_H
                  then Saturating_Add (Row.Y, (Row.Height - Text_H) / 2)
                  else Row.Y);
               Text_W     : constant Natural :=
                 (if Row.Width > Saturating_Add (Glyph_Size, Saturating_Multiply (Root_Selector_Padding, 3))
                  then Row.Width - Saturating_Add (Glyph_Size, Saturating_Multiply (Root_Selector_Padding, 3))
                  else 0);
               Hovered    : constant Boolean :=
                 Has_Hover and then Contains_Point (Row.X, Row.Y, Row.Width, Row.Height, Hover_X, Hover_Y);
               Pressed    : constant Boolean := Is_Pressed (Row.X, Row.Y, Row.Width, Row.Height);
            begin
               Add_Overlay_Rect
                 (Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  (if Row.Selected then Selection_Color
                   elsif Pressed then Pressed_Color
                   elsif Hovered then Hover_Color
                   else Overlay_Color));
               if Index > 1 then
                  Add_Overlay_Rect (Row.X, Row.Y, Row.Width, 1, Border_Color);
               end if;
               if Row.Selected then
                  Add_Overlay_Rect
                    (Row.X,
                     Row.Y,
                     Natural'Min (3, Row.Width),
                     Row.Height,
                     Border_Color);
               end if;
               if Glyph_Size > 0 then
                  Add_Overlay_Rect
                    (Glyph_X,
                     Saturating_Add (Glyph_Y, Glyph_Size / 4),
                     Glyph_Size,
                     Natural'Max (1, Glyph_Size / 2),
                     Icon_Directory_Color);
                  Add_Overlay_Rect
                    (Saturating_Add (Glyph_X, Glyph_Size / 4),
                     Glyph_Y,
                     Natural'Max (1, Glyph_Size / 2),
                     Natural'Max (1, Glyph_Size / 4),
                     Icon_Directory_Color);
               end if;
               Add_Overlay_Text
                 (Text_X,
                  Text_Y,
                  Text_W,
                  Text_H,
                  Snapshot.Root_Labels.Element (Positive (Row.Root_Index)),
                  Fit => True);
               Add_Command_Tooltip
                 (Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  Files.Commands.Open_Selected_Root_Command);
               Add_Accessibility_Node
                 (Role_List_Item,
                  Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  Snapshot.Root_Labels.Element (Positive (Row.Root_Index)),
                  Snapshot.Root_Paths.Element (Positive (Row.Root_Index)),
                  Enabled  => True,
                  Selected => Row.Selected,
                  Focused  => Row.Selected);
            end;
         end loop;
         Draw_Close_Button
           (Root_Selector.X, Root_Selector.Y, Root_Selector.Width, Root_Selector.Height,
            Overlay => True);
      end if;

      if Snapshot.Tree_Panel_Open then
         if Tree_Panel.Width > 0 and then Tree_Panel.Height > 0 then
            Add_Overlay_Rect
              (Saturating_Add (Tree_Panel.X, Tree_Panel.Width),
               Saturating_Add (Tree_Panel.Y, 3),
               3,
               Tree_Panel.Height,
               Pane_Color);
            Add_Overlay_Rect
              (Tree_Panel.X, Tree_Panel.Y, Tree_Panel.Width, Tree_Panel.Height, Overlay_Color);
            Add_Overlay_Border
              (Tree_Panel.X, Tree_Panel.Y, Tree_Panel.Width, Tree_Panel.Height, Border_Color);
            --  Title band.
            Add_Overlay_Rect
              (Tree_Panel.X, Tree_Panel.Y, Tree_Panel.Width, Tree_Panel.Row_Height, Pane_Color);
            Add_Overlay_Rect
              (Tree_Panel.X,
               Saturating_Add (Tree_Panel.Y, Tree_Panel.Row_Height),
               Tree_Panel.Width,
               1,
               Border_Color);
            Add_Overlay_Text
              (Saturating_Add (Tree_Panel.X, Root_Selector_Padding),
               Saturating_Add
                 (Tree_Panel.Y,
                  (if Tree_Panel.Row_Height > Line_Height
                   then (Tree_Panel.Row_Height - Line_Height) / 2
                   else 0)),
               (if Tree_Panel.Width > Saturating_Multiply (Root_Selector_Padding, 2)
                then Tree_Panel.Width - Saturating_Multiply (Root_Selector_Padding, 2)
                else 0),
               Line_Height,
               (if Snapshot.Tree_Pick_Active
                then (if Snapshot.Tree_Pick_Moving
                      then Localized ("tree.pick.move")
                      else Localized ("tree.pick.copy"))
                else Localized ("tree.panel.title")),
               Fit => True);
         end if;

         Add_Accessibility_Node
           (Role_List,
            Tree_Panel.X,
            Tree_Panel.Y,
            Tree_Panel.Width,
            Tree_Panel.Height,
            Localized ("accessibility.tree_panel"));

         for I in 1 .. Natural (Tree_Rows_Layout.Length) loop
            declare
               Row      : constant Tree_Row_Layout := Tree_Rows_Layout.Element (Positive (I));
               Data     : constant Files.Folder_Tree.Visible_Row :=
                 Snapshot.Tree_Rows.Element (Positive (I));
               Label_X  : constant Natural :=
                 Saturating_Add (Row.Triangle_X, Line_Height);
               Label_W  : constant Natural :=
                 (if Saturating_Add (Row.X, Row.Width)
                     > Saturating_Add (Label_X, Root_Selector_Padding)
                  then Saturating_Add (Row.X, Row.Width)
                       - Saturating_Add (Label_X, Root_Selector_Padding)
                  else 0);
               Text_Y   : constant Natural :=
                 (if Row.Height > Line_Height
                  then Saturating_Add (Row.Y, (Row.Height - Line_Height) / 2)
                  else Row.Y);
               Hovered  : constant Boolean :=
                 Has_Hover and then Contains_Point (Row.X, Row.Y, Row.Width, Row.Height, Hover_X, Hover_Y);
               Pressed  : constant Boolean := Is_Pressed (Row.X, Row.Y, Row.Width, Row.Height);
            begin
               Add_Overlay_Rect
                 (Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  (if Row.Selected then Selection_Color
                   elsif Pressed then Pressed_Color
                   elsif Hovered then Hover_Color
                   else Overlay_Color));
               if Row.Has_Children and then Row.Triangle_W > 0 then
                  Add_Overlay_Text
                    (Row.Triangle_X,
                     Text_Y,
                     Row.Triangle_W,
                     Line_Height,
                     To_Unbounded_String
                       (if Row.Expanded
                        then Tree_Expander_Expanded_Text
                        else Tree_Expander_Collapsed_Text),
                     Color => Muted_Text_Color);
               end if;
               Add_Overlay_Text
                 (Label_X,
                  Text_Y,
                  Label_W,
                  Line_Height,
                  Data.Name,
                  Color => Text_Color,
                  Fit   => True);
               Add_Accessibility_Node
                 (Role_List_Item,
                  Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  Data.Name,
                  Data.Path,
                  Enabled  => True,
                  Selected => Row.Selected,
                  Focused  => Row.Selected);
            end;
         end loop;

         --  Destination picker button bar (Choose / Cancel).
         if Snapshot.Tree_Pick_Active then
            declare
               Buttons : constant Tree_Pick_Button_Layout :=
                 Tree_Pick_Buttons (Tree_Panel, Line_Height);

               procedure Draw_Pick_Button (Button_X : Natural; Label_Key : String) is
                  Hovered : constant Boolean :=
                    Has_Hover
                    and then Contains_Point
                               (Button_X, Buttons.Y, Buttons.Button_Width, Buttons.Height,
                                Hover_X, Hover_Y);
                  Pressed : constant Boolean :=
                    Is_Pressed (Button_X, Buttons.Y, Buttons.Button_Width, Buttons.Height);
               begin
                  Guikit.Widgets.Draw_Button
                    (Rectangles      => Result.Overlay_Rectangles,
                     Text            => Result.Overlay_Text,
                     Clip_Width      => Layout.Width,
                     Clip_Height     => Layout.Height,
                     X               => Button_X,
                     Y               => Buttons.Y,
                     Width           => Buttons.Button_Width,
                     Height          => Buttons.Height,
                     Fill_Color      =>
                       (if Pressed then Pressed_Color elsif Hovered then Hover_Color else Pane_Color),
                     Border_Color    => Border_Color,
                     Padding         => Guikit.Layout.Input_Field_Padding,
                     Label_Text      => Localized (Label_Key),
                     Label_Truncated => False,
                     Label_Height    => Line_Height,
                     Label_Color     => Text_Color);
                  Add_Accessibility_Node
                    (Role_Button, Button_X, Buttons.Y, Buttons.Button_Width, Buttons.Height,
                     Localized (Label_Key));
               end Draw_Pick_Button;
            begin
               if Buttons.Visible then
                  Draw_Pick_Button (Buttons.Choose_X, "tree.pick.choose");
                  Draw_Pick_Button (Buttons.Cancel_X, "tree.pick.cancel");
               end if;
            end;
         end if;

         Draw_Close_Button
           (Tree_Panel.X, Tree_Panel.Y, Tree_Panel.Width, Tree_Panel.Height, Overlay => True);
      end if;

      if Snapshot.Context_Menu_Open then
         declare
            Menu : constant Context_Menu_Layout :=
              Calculate_Context_Menu_Layout (Snapshot, Width, Height, Line_Height);
         begin
            if Menu.Visible then
               Guikit.Widgets.Draw_Menu_Panel
                 (Rectangles   => Result.Overlay_Rectangles,
                  Clip_Width   => Layout.Width,
                  Clip_Height  => Layout.Height,
                  X            => Menu.X,
                  Y            => Menu.Y,
                  Width        => Menu.Width,
                  Height       => Menu.Height,
                  Fill_Color   => Pane_Color,
                  Border_Color => Border_Color);

               Add_Accessibility_Node
                 (Role_List,
                  Menu.X, Menu.Y, Menu.Width, Menu.Height,
                  Localized ("command.palette.open"));

               declare
                  --  Fit a menu label to its padded interior exactly as
                  --  Add_Overlay_Text (Fit => True) would, so Draw_Menu_Row
                  --  reproduces the former per-row overlay text byte for byte.
                  Cell_W : constant Positive :=
                    Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);

                  Row_Y : Natural := Menu.Y + Menu.Padding;
               begin
                  for Row in 1 .. Menu.Row_Count loop
                     if Menu.Row_Kinds (Row) = Separator_Row then
                        --  Draw a thin divider centered in the separator row so
                        --  the command groups above and below read as distinct.
                        declare
                           Line_Inset : constant Natural := Menu.Padding;
                           Line_Width : constant Natural :=
                             (if Menu.Width > 2 * Line_Inset
                              then Menu.Width - 2 * Line_Inset
                              else Menu.Width);
                           Line_Y     : constant Natural :=
                             Row_Y + Menu.Separator_Height / 2;
                        begin
                           Guikit.Widgets.Draw_Menu_Row
                             (Rectangles      => Result.Overlay_Rectangles,
                              Text            => Result.Overlay_Text,
                              Clip_Width      => Layout.Width,
                              Clip_Height     => Layout.Height,
                              Row_X           => Menu.X,
                              Row_Y           => Row_Y,
                              Row_Width       => Menu.Width,
                              Row_Height      => Menu.Separator_Height,
                              Is_Separator    => True,
                              Separator_X     => Menu.X + Line_Inset,
                              Separator_Y     => Line_Y,
                              Separator_Width => Line_Width,
                              Separator_Color => Border_Color,
                              Highlight       => False,
                              Highlight_Color => Hover_Color,
                              Label_X         => 0,
                              Label_Y         => 0,
                              Label_Width     => 0,
                              Label_Height    => 0,
                              Label_Text      => Null_Unbounded_String,
                              Label_Truncated => False,
                              Label_Color     => Text_Color);
                        end;
                        Row_Y := Row_Y + Menu.Separator_Height;
                     else
                        declare
                           Command : constant Files.Commands.Command_Id :=
                             Menu.Commands (Row);
                           Enabled : constant Boolean :=
                             Command /= Files.Commands.No_Command
                             and then Snapshot.Command_Enabled (Command);
                           Hovered : constant Boolean :=
                             Has_Hover
                             and then Contains_Point
                               (Menu.X, Row_Y, Menu.Width, Menu.Row_Height,
                                Hover_X, Hover_Y);
                           Pressed : constant Boolean :=
                             Is_Pressed
                               (Menu.X, Row_Y, Menu.Width, Menu.Row_Height);
                           Text_X  : constant Natural :=
                             Menu.X + Guikit.Layout.Input_Field_Padding;
                           Text_Y_Off : constant Natural :=
                             (if Menu.Row_Height > Line_Height
                              then (Menu.Row_Height - Line_Height) / 2
                              else 0);
                           Label_W : constant Natural :=
                             (if Menu.Width > 2 * Guikit.Layout.Input_Field_Padding
                              then Menu.Width - 2 * Guikit.Layout.Input_Field_Padding
                              else 0);
                           Draw_W  : constant Natural :=
                             Clipped_Size (Text_X, Label_W, Layout.Width);
                           Capacity : constant Natural := Draw_W / Cell_W;
                           Raw_Label : constant UString := Command_Label (Command);
                           Fitted    : constant UString :=
                             Fitted_Text_For (Raw_Label, Capacity);
                           --  Highlight fires on press, else on an enabled hover;
                           --  a pressed row wins the color, matching the former
                           --  if/elsif chain.
                           Highlight : constant Boolean :=
                             Pressed or else (Hovered and then Enabled);
                        begin
                           Guikit.Widgets.Draw_Menu_Row
                             (Rectangles      => Result.Overlay_Rectangles,
                              Text            => Result.Overlay_Text,
                              Clip_Width      => Layout.Width,
                              Clip_Height     => Layout.Height,
                              Row_X           => Menu.X,
                              Row_Y           => Row_Y,
                              Row_Width       => Menu.Width,
                              Row_Height      => Menu.Row_Height,
                              Is_Separator    => False,
                              Separator_X     => 0,
                              Separator_Y     => 0,
                              Separator_Width => 0,
                              Separator_Color => Border_Color,
                              Highlight       => Highlight,
                              Highlight_Color =>
                                (if Pressed then Pressed_Color else Hover_Color),
                              Label_X         => Text_X,
                              Label_Y         => Row_Y + Text_Y_Off,
                              Label_Width     => Label_W,
                              Label_Height    => Line_Height,
                              Label_Text      => Fitted,
                              Label_Truncated =>
                                To_String (Fitted) /= To_String (Raw_Label),
                              Label_Color     =>
                                (if Enabled then Text_Color else Disabled_Text_Color));
                           Add_Accessibility_Node
                             (Role_Button,
                              Menu.X, Row_Y, Menu.Width, Menu.Row_Height,
                              Command_Label (Command),
                              Localized (Files.Commands.Description_Key (Command)),
                              Enabled => Enabled);
                        end;
                        Row_Y := Row_Y + Menu.Row_Height;
                     end if;
                  end loop;
               end;
            end if;
         end;
      end if;

      if Snapshot.Paste_Conflict_Open then
         declare
            Dialog : constant Conflict_Dialog_Layout :=
              Calculate_Conflict_Dialog_Layout (Snapshot, Layout, Line_Height);
            Pad    : constant Natural := 12;
            Text_W : constant Natural :=
              (if Dialog.Width > Saturating_Multiply (Pad, 2) then Dialog.Width - Saturating_Multiply (Pad, 2)
               else Dialog.Width);

            procedure Draw_Button (Kind : Conflict_Hit_Kind; Button_X : Natural; Label_Key : String) is
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
                  Padding         => Guikit.Layout.Input_Field_Padding,
                  Label_Text      => Localized (Label_Key),
                  Label_Truncated => False,
                  Label_Height    => Line_Height,
                  Label_Color     => Text_Color);
               Add_Accessibility_Node
                 (Role_Button, Button_X, Dialog.Button_Y, Dialog.Button_Width, Dialog.Button_Height,
                  Localized (Label_Key));
               Result.Conflict_Hits.Append
                 (Conflict_Hit_Region'
                    (Kind   => Kind,
                     X      => Button_X,
                     Y      => Dialog.Button_Y,
                     Width  => Dialog.Button_Width,
                     Height => Dialog.Button_Height));
            end Draw_Button;
         begin
            --  Modal backdrop and panel body.
            Add_Overlay_Rect (Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height, Overlay_Color);
            Add_Overlay_Border (Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height, Border_Color);
            Add_Accessibility_Node
              (Role_Dialog, Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height,
               Localized ("dialog.paste_conflict.title"));

            --  Conflicting name and the "already exists" line.
            Add_Overlay_Text
              (Saturating_Add (Dialog.X, Pad), Saturating_Add (Dialog.Y, Pad), Text_W, Line_Height,
               Snapshot.Paste_Conflict_Name, Text_Color, Fit => True);
            Add_Overlay_Text
              (Saturating_Add (Dialog.X, Pad), Saturating_Add (Dialog.Y, Saturating_Add (Pad, Line_Height)),
               Text_W, Line_Height, Localized ("dialog.paste_conflict.exists"), Text_Color, Fit => True);

            --  "Apply to all remaining" toggle row.
            declare
               Box_Size : constant Natural := Natural'Min (Line_Height, Dialog.Apply_Height);
               Hovered  : constant Boolean :=
                 Has_Hover
                 and then Contains_Point
                            (Dialog.Apply_X, Dialog.Apply_Y, Dialog.Apply_Width, Dialog.Apply_Height,
                             Hover_X, Hover_Y);
            begin
               if Hovered then
                  Add_Overlay_Rect
                    (Dialog.Apply_X, Dialog.Apply_Y, Dialog.Apply_Width, Dialog.Apply_Height, Hover_Color);
               end if;
               Add_Overlay_Rect (Dialog.Apply_X, Dialog.Apply_Y, Box_Size, Box_Size, Border_Color);
               Add_Overlay_Rect
                 (Saturating_Add (Dialog.Apply_X, 1), Saturating_Add (Dialog.Apply_Y, 1),
                  (if Box_Size > 2 then Box_Size - 2 else 0), (if Box_Size > 2 then Box_Size - 2 else 0),
                  (if Snapshot.Paste_Conflict_Apply_All then Selection_Color else Overlay_Color));
               Add_Overlay_Text
                 (Saturating_Add (Dialog.Apply_X, Saturating_Add (Box_Size, Guikit.Layout.Input_Field_Padding)),
                  Dialog.Apply_Y,
                  (if Dialog.Apply_Width > Saturating_Add (Box_Size, Guikit.Layout.Input_Field_Padding)
                   then Dialog.Apply_Width - Saturating_Add (Box_Size, Guikit.Layout.Input_Field_Padding)
                   else Dialog.Apply_Width),
                  Line_Height, Localized ("dialog.paste_conflict.apply_to_all"), Text_Color, Fit => True);
               Add_Accessibility_Node
                 (Role_Button, Dialog.Apply_X, Dialog.Apply_Y, Dialog.Apply_Width, Dialog.Apply_Height,
                  Localized ("dialog.paste_conflict.apply_to_all"),
                  Selected => Snapshot.Paste_Conflict_Apply_All);
               Result.Conflict_Hits.Append
                 (Conflict_Hit_Region'
                    (Kind   => Conflict_Hit_Apply_All,
                     X      => Dialog.Apply_X,
                     Y      => Dialog.Apply_Y,
                     Width  => Dialog.Apply_Width,
                     Height => Dialog.Apply_Height));
            end;

            Draw_Button (Conflict_Hit_Replace, Dialog.Replace_X, "dialog.paste_conflict.button.replace");
            Draw_Button (Conflict_Hit_Skip, Dialog.Skip_X, "dialog.paste_conflict.button.skip");
            Draw_Button (Conflict_Hit_Rename, Dialog.Rename_X, "dialog.paste_conflict.button.rename");
            Draw_Button (Conflict_Hit_Cancel, Dialog.Cancel_X, "dialog.paste_conflict.button.cancel");

            --  Close button in the panel corner cancels the whole paste.
            Draw_Close_Button (Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height, Overlay => True);
         end;
      end if;

      if Snapshot.Paste_Progress_Open then
         declare
            Panel  : constant Paste_Progress_Layout :=
              Calculate_Paste_Progress_Layout (Snapshot, Layout, Line_Height);
            Pad    : constant Natural := 12;
            Text_W : constant Natural :=
              (if Panel.Width > Saturating_Multiply (Pad, 2) then Panel.Width - Saturating_Multiply (Pad, 2)
               else Panel.Width);
            Verb_Key : constant String :=
              (if Snapshot.Paste_Progress_Moving
               then "dialog.paste_progress.moving"
               else "dialog.paste_progress.copying");
            Count_Line : constant UString :=
              Localized (Verb_Key)
              & To_Unbounded_String (" ")
              & To_Unbounded_String (Grouped_Integer_Text (Long_Long_Integer (Snapshot.Paste_Progress_Done)))
              & To_Unbounded_String (" ")
              & Localized ("dialog.paste_progress.of")
              & To_Unbounded_String (" ")
              & To_Unbounded_String (Grouped_Integer_Text (Long_Long_Integer (Snapshot.Paste_Progress_Total)));
            Cancel_Hovered : constant Boolean :=
              Has_Hover
              and then Contains_Point
                         (Panel.Cancel_X, Panel.Cancel_Y, Panel.Cancel_Width, Panel.Cancel_Height,
                          Hover_X, Hover_Y);
            Cancel_Pressed : constant Boolean :=
              Is_Pressed (Panel.Cancel_X, Panel.Cancel_Y, Panel.Cancel_Width, Panel.Cancel_Height);
         begin
            --  Modal-lite panel body and border.
            Add_Overlay_Rect (Panel.X, Panel.Y, Panel.Width, Panel.Height, Overlay_Color);
            Add_Overlay_Border (Panel.X, Panel.Y, Panel.Width, Panel.Height, Border_Color);
            Add_Accessibility_Node
              (Role_Dialog, Panel.X, Panel.Y, Panel.Width, Panel.Height,
               Localized ("dialog.paste_progress.title"));

            --  "Copying/Moving N of M" plus the current item name.
            Add_Overlay_Text
              (Saturating_Add (Panel.X, Pad), Saturating_Add (Panel.Y, Pad), Text_W, Line_Height,
               Count_Line, Text_Color, Fit => True);
            Add_Overlay_Text
              (Saturating_Add (Panel.X, Pad),
               Saturating_Add (Panel.Y, Saturating_Add (Pad, Line_Height)),
               Text_W, Line_Height, Snapshot.Paste_Progress_Name, Muted_Text_Color, Fit => True);

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
            Result.Conflict_Hits.Append
              (Conflict_Hit_Region'
                 (Kind   => Conflict_Hit_Progress_Cancel,
                  X      => Panel.Cancel_X,
                  Y      => Panel.Cancel_Y,
                  Width  => Panel.Cancel_Width,
                  Height => Panel.Cancel_Height));
         end;
      end if;
   end Draw_Overlay_Commands;
