separate (Files.Rendering.Build_Frame_Commands.Draw_Overlay_Commands)
   --  The context menu.
   procedure Draw_Context_Menu is
      use type Files.Commands.Context_Menu_Row_Kind;
      Menu : constant Context_Menu_Layout :=
        Calculate_Context_Menu_Layout (Snapshot, Width, Height, Line_Height);
      --  Fit a menu label to its padded interior exactly as
      --  Add_Overlay_Text (Fit => True) fits overlay text, so a row's
      --  label is cut where any other fitted overlay text would be.
      Cell_W : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);

      --  A thin divider centered in a separator row, inset by the menu's
      --  padding, so the command groups above and below read as distinct.
      procedure Add_Separator (Row_X, Row_Y, Row_W : Natural) is
         Line_Inset : constant Natural := Menu.Padding;
      begin
         Add_Overlay_Rect
           (Row_X + Line_Inset,
            Row_Y + Menu.Separator_Height / 2,
            (if Row_W > 2 * Line_Inset then Row_W - 2 * Line_Inset else Row_W),
            1,
            Border_Color);
      end Add_Separator;

      --  A command row at Row_X, Row_Y, Row_W: its highlight, its fitted
      --  label (dimmed when disabled) and its accessibility node.
      procedure Draw_Command_Row (Row : Positive; Row_X, Row_Y, Row_W : Natural) is
         Command : constant Files.Commands.Command_Id :=
           Menu.Rows (Row).Command;
         Enabled : constant Boolean :=
           Command /= Files.Commands.No_Command
           and then Snapshot.Command_Enabled (Command);
         Hovered : constant Boolean :=
           Is_Hovered (Row_X, Row_Y, Row_W, Menu.Row_Height);
         Pressed : constant Boolean :=
           Is_Pressed
             (Row_X, Row_Y, Row_W, Menu.Row_Height);
         Text_X  : constant Natural :=
           Row_X + Files.Rendering.Layouts.Field_Padding (Line_Height);
         Text_Y_Off : constant Natural :=
           (if Menu.Row_Height > Line_Height
            then (Menu.Row_Height - Line_Height) / 2
            else 0);
         Label_W : constant Natural :=
           (if Row_W > 2 * Files.Rendering.Layouts.Field_Padding (Line_Height)
            then Row_W - 2 * Files.Rendering.Layouts.Field_Padding (Line_Height)
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
      end Draw_Command_Row;
   begin
      if not Menu.Visible then
         return;
      end if;
      --  The shell consumes the next click to choose or dismiss this
      --  menu, so publish only its active choices to screen readers.
      Draw_Modal_Chrome
        (Menu.X, Menu.Y, Menu.Width, Menu.Height, Overlay_Color, Role_List, Localized ("accessibility.context_menu"));

      for Row in 1 .. Menu.Row_Count loop
         declare
            Row_X : constant Natural := Context_Menu_Row_Left (Menu, Row);
            Row_Y : constant Natural := Context_Menu_Row_Top (Menu, Row);
            Row_W : constant Natural := Context_Menu_Row_Width (Menu, Row);
         begin
            if Menu.Rows (Row).Kind = Files.Commands.Menu_Separator then
               Add_Separator (Row_X, Row_Y, Row_W);
            else
               Draw_Command_Row (Row, Row_X, Row_Y, Row_W);
            end if;
         end;
      end loop;

      if Menu.Column_Count > 1 and then Menu.Column_Width > 0 then
         Add_Overlay_Rect
           (Guikit.Layout.Saturating_Add (Menu.X, Menu.Column_Width),
            Menu.Y,
            1,
            Menu.Height,
            Border_Color);
      end if;
   end Draw_Context_Menu;
