separate (Files.Rendering.Build_Frame_Commands.Draw_Overlay_Commands)
   --  The context menu.
   procedure Draw_Context_Menu is
      use type Files.Commands.Context_Menu_Row_Kind;
   begin
      declare
         Menu : constant Context_Menu_Layout :=
           Calculate_Context_Menu_Layout (Snapshot, Width, Height, Line_Height);
      begin
         if Menu.Visible then
            --  The shell consumes the next click to choose or dismiss this
            --  menu, so publish only its active choices to screen readers.
            Result.Accessibility.Clear;
            Add_Overlay_Drop_Shadow (Menu.X, Menu.Y, Menu.Width, Menu.Height);
            Guikit.Widgets.Draw_Menu_Panel
              (Rectangles   => Result.Overlay_Rectangles,
               Clip_Width   => Layout.Width,
               Clip_Height  => Layout.Height,
               X            => Menu.X,
               Y            => Menu.Y,
               Width        => Menu.Width,
               Height       => Menu.Height,
               Fill_Color   => Overlay_Color,
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
                 Guikit.Layout.Caret_Advance_Width (Line_Height);
            begin
               for Row in 1 .. Menu.Row_Count loop
                  declare
                     Row_X : constant Natural := Context_Menu_Row_Left (Menu, Row);
                     Row_Y : constant Natural := Context_Menu_Row_Top (Menu, Row);
                     Row_W : constant Natural := Context_Menu_Row_Width (Menu, Row);
                  begin
                     if Menu.Rows (Row).Kind = Files.Commands.Menu_Separator then
                        --  Draw a thin divider centered in the separator row so
                        --  the command groups above and below read as distinct.
                        declare
                           Line_Inset : constant Natural := Menu.Padding;
                           Line_Width : constant Natural :=
                             (if Row_W > 2 * Line_Inset
                              then Row_W - 2 * Line_Inset
                              else Row_W);
                           Line_Y     : constant Natural :=
                             Row_Y + Menu.Separator_Height / 2;
                        begin
                           Guikit.Widgets.Draw_Menu_Row
                             (Rectangles      => Result.Overlay_Rectangles,
                              Text            => Result.Overlay_Text,
                              Clip_Width      => Layout.Width,
                              Clip_Height     => Layout.Height,
                              Row_X           => Row_X,
                              Row_Y           => Row_Y,
                              Row_Width       => Row_W,
                              Row_Height      => Menu.Separator_Height,
                              Is_Separator    => True,
                              Separator_X     => Row_X + Line_Inset,
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
                     else
                        declare
                           Command : constant Files.Commands.Command_Id :=
                             Menu.Rows (Row).Command;
                           Enabled : constant Boolean :=
                             Command /= Files.Commands.No_Command
                             and then Snapshot.Command_Enabled (Command);
                           Hovered : constant Boolean :=
                             Has_Hover
                             and then Contains_Point
                               (Row_X, Row_Y, Row_W, Menu.Row_Height,
                                Hover_X, Hover_Y);
                           Pressed : constant Boolean :=
                             Is_Pressed
                               (Row_X, Row_Y, Row_W, Menu.Row_Height);
                           Text_X  : constant Natural :=
                             Row_X + Files.UI.Field_Padding (Line_Height);
                           Text_Y_Off : constant Natural :=
                             (if Menu.Row_Height > Line_Height
                              then (Menu.Row_Height - Line_Height) / 2
                              else 0);
                           Label_W : constant Natural :=
                             (if Row_W > 2 * Files.UI.Field_Padding (Line_Height)
                              then Row_W - 2 * Files.UI.Field_Padding (Line_Height)
                              else 0);
                           Draw_W  : constant Natural :=
                             Clipped_Size (Text_X, Label_W, Layout.Width);
                           Capacity : constant Natural := Draw_W / Cell_W;
                           Raw_Label : constant UString := Command_Label (Command);
                           Fitted    : constant UString :=
                             Fitted_Text_For (Raw_Label, Capacity);
                           --  Highlight fires on press, on an enabled hover,
                           --  or on the keyboard-highlighted row (arrow
                           --  navigation), so a keyboard user sees which
                           --  command Enter will run.
                           Highlight : constant Boolean :=
                             Pressed
                             or else (Hovered and then Enabled)
                             or else Row = Snapshot.Context_Menu_Highlight;
                        begin
                           Guikit.Widgets.Draw_Menu_Row
                             (Rectangles      => Result.Overlay_Rectangles,
                              Text            => Result.Overlay_Text,
                              Clip_Width      => Layout.Width,
                              Clip_Height     => Layout.Height,
                              Row_X           => Row_X,
                              Row_Y           => Row_Y,
                              Row_Width       => Row_W,
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
                              Row_X, Row_Y, Row_W, Menu.Row_Height,
                              Command_Label (Command),
                              Localized (Files.Commands.Description_Key (Command)),
                              Enabled => Enabled);
                        end;
                     end if;
                  end;
               end loop;

               if Menu.Column_Count > 1 and then Menu.Column_Width > 0 then
                  Add_Overlay_Rect
                    (Saturating_Add (Menu.X, Menu.Column_Width),
                     Menu.Y,
                     1,
                     Menu.Height,
                     Border_Color);
               end if;
            end;
         end if;
      end;
   end Draw_Context_Menu;
