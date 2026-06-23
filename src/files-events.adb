with Ada.Strings.Unbounded;

with Files.UTF8;
with Files.UI;

package body Files.Events is
   use Ada.Strings.Unbounded;
   use type Files.Commands.Command_Id;
   use type Files.Types.Focus_Target;
   use type Files.Types.Key_Code;
   use type Files.Types.Modifier_Set;

   function No_Action
     (Activate : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind            => No_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => Files.Types.Move_Right,
         Item_Index      => 0,
         Root_Index      => 0,
         Result_Index    => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => Activate,
         Toggle_Selection => False,
         Range_Selection  => False);
   end No_Action;

   function Command_Action
     (Command  : Files.Commands.Command_Id;
      Activate : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind            => Command_Input_Action,
         Command         => Command,
         Direction       => Files.Types.Move_Right,
         Item_Index      => 0,
         Root_Index      => 0,
         Result_Index    => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => Activate,
         Toggle_Selection => False,
         Range_Selection  => False);
   end Command_Action;

   function Selection_Action
     (Direction : Files.Types.Navigation_Direction)
      return Input_Action is
   begin
      return
        (Kind            => Selection_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => Direction,
         Item_Index      => 0,
         Root_Index      => 0,
         Result_Index    => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => False,
         Toggle_Selection => False,
         Range_Selection  => False);
   end Selection_Action;

   function Scroll_Action
     (Target : Scroll_Target;
      Lines  : Integer;
      Activate : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind            => Scroll_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => (if Lines < 0 then Files.Types.Move_Up else Files.Types.Move_Down),
         Item_Index      => 0,
         Root_Index      => 0,
         Result_Index    => 0,
         Scroll_Lines    => Lines,
         Scroll_Area     => Target,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => Activate,
         Toggle_Selection => False,
         Range_Selection  => False);
   end Scroll_Action;

   function Saturating_Negated_Triple (Value : Integer) return Integer is
   begin
      if Value = 0 then
         return 0;
      elsif Value > 0 then
         if Value > Integer'Last / 3 then
            return Integer'First;
         else
            return -(Value * 3);
         end if;
      elsif Value < Integer'First / 3 then
         return Integer'Last;
      else
         return (-Value) * 3;
      end if;
   end Saturating_Negated_Triple;

   function Translate_Key
     (Key       : Files.Types.Key_Code;
      Modifiers : Files.Types.Modifier_Set)
      return Input_Action
   is
      Command : constant Files.Commands.Command_Id := Files.Commands.Find_By_Shortcut (Key, Modifiers);
   begin
      if Command /= Files.Commands.No_Command then
         return Command_Action (Command);
      end if;

      if Modifiers = Files.Types.No_Modifiers then
         case Key is
            when Files.Types.Key_Left =>
               return Selection_Action (Files.Types.Move_Left);
            when Files.Types.Key_Right =>
               return Selection_Action (Files.Types.Move_Right);
            when Files.Types.Key_Up =>
               return Selection_Action (Files.Types.Move_Up);
            when Files.Types.Key_Down =>
               return Selection_Action (Files.Types.Move_Down);
            when others =>
               null;
         end case;
      end if;

      return No_Action;
   end Translate_Key;

   function Translate_Click
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Activate    : Boolean := False;
      Modifiers   : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Line_Height : Positive := 20)
      return Input_Action
   is
      Layout         : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Width, Height, Line_Height);
      Toolbar        : constant Files.UI.Toolbar_Layout := Files.UI.Calculate_Toolbar_Layout (Width);
      Toolbar_Input_Y : constant Natural := Files.UI.Toolbar_Input_Y (Line_Height);
      Toolbar_Input_H : constant Natural := Files.UI.Toolbar_Input_Height (Line_Height);
      Palette_Layout : constant Files.Rendering.Command_Palette_Layout :=
        Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height);
      Palette_Rows   : constant Files.Rendering.Command_Result_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Command_Result_Layout (Snapshot, Palette_Layout);
      Main_View      : constant Files.Rendering.Main_View_Layout :=
        Files.Rendering.Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
      Info_Pane      : constant Files.Rendering.Info_Pane_Layout :=
        Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height);
      Root_Layout    : constant Files.Rendering.Root_Selector_Layout :=
        Files.Rendering.Calculate_Root_Selector_Layout (Snapshot, Layout, Line_Height);
      Root_Rows      : constant Files.Rendering.Root_Path_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Root_Path_Layout (Snapshot, Root_Layout);
      Item_Layout    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height);
      Result_Index   : constant Natural := Files.Rendering.Command_Result_At (Palette_Rows, X, Y);
      Root_Index     : constant Natural := Files.Rendering.Root_Path_At (Root_Rows, X, Y);
      Command        : Files.Commands.Command_Id := Files.Commands.No_Command;
      Item_Index     : Natural := 0;

      function Within
        (Value      : Natural;
         Start      : Natural;
         Extent     : Natural)
         return Boolean is
      begin
         return Extent > 0
           and then Value >= Start
           and then Value - Start < Extent;
      end Within;

      function Scaled_Down
        (Value       : Natural;
         Numerator   : Positive;
         Denominator : Positive)
         return Natural is
      begin
         declare
            Whole : constant Natural := Value / Denominator;
            Part  : constant Natural := Value mod Denominator;
            Whole_Product : Natural;
            Part_Product  : Natural;
         begin
            if Whole > Natural'Last / Numerator then
               Whole_Product := Natural'Last;
            else
               Whole_Product := Whole * Numerator;
            end if;

            if Part > Natural'Last / Numerator then
               Part_Product := Natural'Last;
            else
               Part_Product := Part * Numerator;
            end if;

            if Whole_Product > Natural'Last - (Part_Product / Denominator) then
               return Natural'Last;
            end if;

            return Whole_Product + Part_Product / Denominator;
         end;
      end Scaled_Down;

      function Saturating_Add
        (Left  : Natural;
         Right : Natural)
         return Natural is
      begin
         if Left > Natural'Last - Right then
            return Natural'Last;
         else
            return Left + Right;
         end if;
      end Saturating_Add;

      function Saturating_Multiply
        (Value  : Natural;
         Factor : Natural)
         return Natural is
      begin
         if Factor = 0 then
            return 0;
         elsif Value > Natural'Last / Factor then
            return Natural'Last;
         else
            return Value * Factor;
         end if;
      end Saturating_Multiply;

      function Bounded_Product_Divide
        (Value       : Natural;
         Factor      : Natural;
         Denominator : Positive)
         return Natural is
      begin
         if Factor = 0 or else Value = 0 then
            return 0;
         elsif Value > Natural'Last / Factor then
            return Scaled_Down (Value, Factor, Denominator);
         else
            return (Value * Factor) / Denominator;
         end if;
      end Bounded_Product_Divide;

      function Visible_Row_Count
        (Available_Height : Natural;
         Row_Height       : Natural)
         return Natural is
      begin
         if Available_Height = 0 or else Row_Height = 0 then
            return 0;
         end if;

         return Available_Height / Row_Height
           + (if Available_Height mod Row_Height = 0 then 0 else 1);
      end Visible_Row_Count;

      function Cursor_At
        (Text        : Unbounded_String;
         Text_X      : Natural;
         Click_X     : Natural)
         return Natural
      is
         Char_W : constant Positive := Positive'Max (1, Line_Height / 2);
         Raw    : constant String := To_String (Text);
         Click_Column : Natural;
      begin
         if Click_X <= Text_X then
            return 0;
         end if;

         Click_Column := Saturating_Add (Click_X - Text_X, Char_W / 2) / Char_W;
         return Files.UTF8.Byte_Offset_For_Display_Column (Raw, Click_Column);
      end Cursor_At;

      function Text_Click
        (Target : Files.Types.Focus_Target;
         Cursor : Natural)
         return Input_Action is
      begin
         return
           (Kind            => Text_Click_Input_Action,
            Command         => Files.Commands.No_Command,
            Direction       => Files.Types.Move_Right,
            Item_Index      => 0,
            Root_Index      => 0,
            Result_Index    => 0,
            Scroll_Lines    => 0,
            Scroll_Area     => Scroll_Auto,
            Focus_Target    => Target,
            Cursor_Position => Cursor,
            Settings_Field  => 0,
            Settings_Option => 0,
            Activate        => Activate,
            Toggle_Selection => False,
            Range_Selection  => False);
      end Text_Click;

      function Scroll_Click
        (Target  : Scroll_Target;
         Thumb_Y : Natural;
         Thumb_Height : Natural;
         Y_Pos   : Natural;
         Step    : Positive)
         return Input_Action
      is
         Lines : constant Integer := (if Y_Pos < Thumb_Y then -Integer (Step) else Integer (Step));
      begin
         if Thumb_Height > 0
           and then Y_Pos >= Thumb_Y
           and then Y_Pos - Thumb_Y < Thumb_Height
         then
            return No_Action (Activate);
         end if;

         return Scroll_Action (Target, Lines, Activate);
      end Scroll_Click;

      function Palette_Scrollbar_Click return Input_Action is
         Result_Count : constant Natural := Natural (Snapshot.Command_Palette_Results.Length);
         Visible_Rows : constant Natural :=
           Visible_Row_Count (Palette_Layout.Results_Height, Palette_Layout.Row_Height);
         Bar_W       : constant Natural := Natural'Min (6, Palette_Layout.Results_Width);
         Track_X     : constant Natural :=
           Saturating_Add (Palette_Layout.Results_X, Palette_Layout.Results_Width - Bar_W);
         Track_H     : constant Natural := Palette_Layout.Results_Height;
         Thumb_H     : Natural := 0;
         Thumb_Y     : Natural := Palette_Layout.Results_Y;
         Max_Offset  : Natural := 0;
      begin
         if not Snapshot.Command_Palette_Open
           or else Result_Count = 0
           or else Visible_Rows = 0
           or else Result_Count <= Visible_Rows
           or else Track_H = 0
           or else not Within (X, Track_X, Bar_W)
           or else not Within (Y, Palette_Layout.Results_Y, Track_H)
         then
            return No_Action (Activate);
         end if;

         Max_Offset := Result_Count - Visible_Rows;
         Thumb_H :=
           Natural'Max
             (Palette_Layout.Row_Height,
              Bounded_Product_Divide (Value => Track_H, Factor => Visible_Rows, Denominator => Result_Count));
         Thumb_H := Natural'Min (Thumb_H, Track_H);
         if Max_Offset > 0 and then Track_H > Thumb_H then
            Thumb_Y :=
              Saturating_Add
                (Palette_Layout.Results_Y,
                 Bounded_Product_Divide
                   (Value       => Track_H - Thumb_H,
                    Factor      => Natural'Min (Snapshot.Command_Palette_Result_Offset, Max_Offset),
                    Denominator => Max_Offset));
         end if;

         return Scroll_Click (Scroll_Command_Palette, Thumb_Y, Thumb_H, Y, 5);
      end Palette_Scrollbar_Click;

      function Palette_Scrollbar_Hit return Boolean is
         Result_Count : constant Natural := Natural (Snapshot.Command_Palette_Results.Length);
         Visible_Rows : constant Natural :=
           Visible_Row_Count (Palette_Layout.Results_Height, Palette_Layout.Row_Height);
         Bar_W        : constant Natural := Natural'Min (6, Palette_Layout.Results_Width);
         Track_X      : constant Natural :=
           Saturating_Add (Palette_Layout.Results_X, Palette_Layout.Results_Width - Bar_W);
      begin
         return Snapshot.Command_Palette_Open
           and then Result_Count > Visible_Rows
           and then Visible_Rows > 0
           and then Within (X, Track_X, Bar_W)
           and then Within (Y, Palette_Layout.Results_Y, Palette_Layout.Results_Height);
      end Palette_Scrollbar_Hit;

      function Settings_Click
        (Field  : Natural;
         Option : Natural := 0)
         return Input_Action is
      begin
         return
           (Kind            => Settings_Click_Input_Action,
            Command         => Files.Commands.No_Command,
            Direction       => Files.Types.Move_Right,
            Item_Index      => 0,
            Root_Index      => 0,
            Result_Index    => 0,
            Scroll_Lines    => 0,
            Scroll_Area     => Scroll_Auto,
            Focus_Target    => Files.Types.Focus_Settings_Input,
            Cursor_Position => 0,
            Settings_Field  => Field,
            Settings_Option => Option,
            Activate        => Activate,
            Toggle_Selection => False,
            Range_Selection  => False);
      end Settings_Click;

      function Settings_Click_Hit return Input_Action is
         Pane : constant Files.UI.Settings_Pane_Layout :=
           Files.UI.Calculate_Settings_Pane_Layout (Width, Height, Layout.Toolbar_Height, Line_Height);
         Pane_W : constant Natural := Pane.Width;
         Pane_H : constant Natural := Pane.Height;
         Pane_X : constant Natural := Pane.X;
         Pane_Y : constant Natural := Pane.Y;
         Entry_Buttons : constant Files.UI.Settings_Entry_Button_Layout :=
           Files.UI.Calculate_Settings_Entry_Button_Layout (Pane_X, Pane_W, Line_Height);
         Text_X : constant Natural := Pane.Text_X;
         Text_W : constant Natural := Pane.Text_Width;
         Action_Buttons : constant Files.UI.Settings_Action_Button_Layout :=
           Files.UI.Calculate_Settings_Action_Button_Layout (Text_X, Text_W);
         Row    : Natural;
         Cell_W : Natural;

         function Option_Count (Field : Natural) return Natural is
         begin
            case Field is
               when 1 =>
                  return 3;
               when 2 | 3 | 5 | 6 | 7 =>
                  return 2;
               when 4 =>
                  return 4;
               when others =>
                  return 0;
            end case;
         end Option_Count;

         function Option_Hit_Width (Field : Natural) return Natural is
            Count : constant Natural := Option_Count (Field);
         begin
            if Count = 0 or else Cell_W = 0 then
               return 0;
            elsif Count = 4 then
               return Text_W;
            else
               return Natural'Min (Text_W, Saturating_Multiply (Count, Cell_W));
            end if;
         end Option_Hit_Width;

         function Row_Field return Natural is
         begin
            case Row is
               when 3 => return 1;
               when 4 => return 2;
               when 5 => return 3;
               when 6 => return 4;
               when 7 => return 5;
               when 8 => return 6;
               when 9 => return 7;
               when 11 => return 8;
               when 12 => return 9;
               when 14 => return 10;
               when 15 => return 11;
               when 17 => return 12;
               when 18 => return 13;
               when others => return 0;
            end case;
         end Row_Field;

         function Settings_Command_Click
         (Command : Files.Commands.Command_Id)
            return Input_Action is
         begin
            case Command is
               when Files.Commands.Import_Settings_Command =>
                  if Snapshot.Settings_Can_Import then
                     return Command_Action (Command, Activate);
                  end if;
               when Files.Commands.Export_Settings_Command =>
                  if Snapshot.Settings_Can_Export then
                     return Command_Action (Command, Activate);
                  end if;
               when Files.Commands.Reset_Settings_Command =>
                  if Snapshot.Settings_Can_Reset then
                     return Command_Action (Command, Activate);
                  end if;
               when Files.Commands.Save_Settings_Command =>
                  if Snapshot.Settings_Can_Save then
                     return Command_Action (Command, Activate);
                  end if;
               when others =>
                  return Command_Action (Command, Activate);
            end case;

            return No_Action (Activate);
         end Settings_Command_Click;
      begin
         if not Snapshot.Settings_Pane_Open
           or else not Within (X, Pane_X, Pane_W)
           or else not Within (Y, Pane_Y, Pane_H)
         then
            return No_Action (Activate);
         end if;

         Row := (Y - Pane_Y) / Line_Height;
         if Row in 1 .. 2
           and then Within (X, Action_Buttons.Total_X, Action_Buttons.Total_Width)
         then
            if Row = 1
              and then Within (X, Action_Buttons.First_Button_X, Action_Buttons.First_Button_Width)
            then
               return Settings_Command_Click (Files.Commands.Import_Settings_Command);
            elsif Row = 1
              and then Within (X, Action_Buttons.Second_Button_X, Action_Buttons.Second_Button_Width)
            then
               return Settings_Command_Click (Files.Commands.Export_Settings_Command);
            elsif Row = 2
              and then Within (X, Action_Buttons.First_Button_X, Action_Buttons.First_Button_Width)
            then
               return Settings_Command_Click (Files.Commands.Reset_Settings_Command);
            elsif Row = 2
              and then Within (X, Action_Buttons.Second_Button_X, Action_Buttons.Second_Button_Width)
            then
               return Settings_Command_Click (Files.Commands.Save_Settings_Command);
            end if;
         elsif Row = 21 and then Snapshot.Settings_Field_Index in 1 .. 7 then
            Cell_W := (if Text_W > 0 then Text_W / 4 else 0);
            if Cell_W > 0
              and then Within
                (X,
                 Text_X,
                 Option_Hit_Width (Snapshot.Settings_Field_Index))
            then
               return
                 Settings_Click
                   (Snapshot.Settings_Field_Index,
                    Natural'Min
                      (Option_Count (Snapshot.Settings_Field_Index),
                       (X - Text_X) / Cell_W + 1));
            end if;
         elsif Row in 10 | 13 | 16 and then Within (X, Entry_Buttons.Total_X, Entry_Buttons.Total_Width) then
            declare
               Field : constant Natural := (case Row is when 10 => 8, when 13 => 10, when others => 12);
            begin
               if Within (X, Entry_Buttons.Add_Button_X, Entry_Buttons.Add_Button_Width) then
                  return Settings_Click (Field, 100);
               elsif Within (X, Entry_Buttons.Remove_Button_X, Entry_Buttons.Remove_Button_Width) then
                  return Settings_Click (Field, 101);
               end if;
            end;
         elsif Row_Field /= 0 then
            return Settings_Click (Row_Field);
         end if;

         return No_Action (Activate);
      end Settings_Click_Hit;
   begin
      declare
         Palette_Scroll : constant Input_Action := Palette_Scrollbar_Click;
      begin
         if Palette_Scroll.Kind /= No_Input_Action then
            return Palette_Scroll;
         elsif Palette_Scrollbar_Hit then
            return No_Action (Activate);
         end if;
      end;

      if Snapshot.Command_Palette_Open
        and then Within (X, Palette_Layout.Search_X, Palette_Layout.Search_Width)
        and then Within (Y, Palette_Layout.Search_Y, Palette_Layout.Search_Height)
      then
         return
           Text_Click
             (Files.Types.Focus_Command_Palette,
              Cursor_At
                 (Text        => Snapshot.Command_Palette_Query,
                 Text_X      => Saturating_Add (Palette_Layout.Search_X, Files.UI.Input_Field_Padding),
                 Click_X     => X));
      end if;

      if Result_Index /= 0 then
         return
           (Kind            => Command_Result_Click_Input_Action,
            Command         => Files.Commands.No_Command,
            Direction       => Files.Types.Move_Right,
            Item_Index      => 0,
            Root_Index      => 0,
            Result_Index    => Result_Index,
            Scroll_Lines    => 0,
            Scroll_Area     => Scroll_Auto,
            Focus_Target    => Files.Types.Focus_None,
            Cursor_Position => 0,
            Settings_Field  => 0,
            Settings_Option => 0,
            Activate        => Activate,
            Toggle_Selection => False,
            Range_Selection  => False);
      elsif Snapshot.Command_Palette_Open then
         return No_Action (Activate);
      elsif Root_Index /= 0 then
         return
           (Kind            => Root_Click_Input_Action,
            Command         => Files.Commands.No_Command,
            Direction       => Files.Types.Move_Right,
            Item_Index      => 0,
            Root_Index      => Root_Index,
            Result_Index    => 0,
            Scroll_Lines    => 0,
            Scroll_Area     => Scroll_Auto,
            Focus_Target    => Files.Types.Focus_None,
            Cursor_Position => 0,
            Settings_Field  => 0,
            Settings_Option => 0,
            Activate        => Activate,
            Toggle_Selection => False,
            Range_Selection  => False);
      elsif Snapshot.Root_Selector_Open then
         declare
            Root_Command : constant Files.Commands.Command_Id :=
              Files.UI.Toolbar_Command_At (X, Y, Width, Line_Height);
         begin
            if Root_Command = Files.Commands.Select_Drive_Command then
               return Command_Action (Root_Command, Activate);
            end if;
         end;
         return No_Action (Activate);
      end if;

      declare
         Hit : constant Input_Action := Settings_Click_Hit;
      begin
         if Hit.Kind /= No_Input_Action then
            return Hit;
         elsif Snapshot.Settings_Pane_Open then
            return No_Action (Activate);
         end if;
      end;

      if Info_Pane.Scrollbar_Visible
        and then Within (X, Info_Pane.Scrollbar_X, Info_Pane.Scrollbar_Width)
        and then Within (Y, Info_Pane.Scrollbar_Y, Info_Pane.Scrollbar_Track_Height)
      then
         return
           Scroll_Click
             (Scroll_Info_Pane,
              Info_Pane.Scrollbar_Thumb_Y,
              Info_Pane.Scrollbar_Height,
              Y,
              10);
      elsif Main_View.Scrollbar_Visible
        and then Within (X, Main_View.Scrollbar_X, Main_View.Scrollbar_Width)
        and then Within (Y, Main_View.Scrollbar_Y, Main_View.Scrollbar_Track_Height)
      then
         return
           Scroll_Click
             (Scroll_Main_View,
              Main_View.Scrollbar_Thumb_Y,
              Main_View.Scrollbar_Height,
              Y,
              10);
      end if;

      if Within (X, Toolbar.Middle_X, Toolbar.Middle_Width)
        and then Within (Y, Toolbar_Input_Y, Toolbar_Input_H)
      then
         return
           Text_Click
             (Files.Types.Focus_Path_Input,
              Cursor_At
                 (Text        => Snapshot.Path_Input_Text,
                 Text_X      => Saturating_Add (Toolbar.Middle_X, Files.UI.Input_Field_Padding),
                 Click_X     => X));
      elsif Within (X, Toolbar.Right_X, Toolbar.Right_Width)
        and then Within (Y, Toolbar_Input_Y, Toolbar_Input_H)
      then
         return
           Text_Click
             (Files.Types.Focus_Filter_Input,
              Cursor_At
                 (Text        => Snapshot.Filter_Text,
                 Text_X      => Saturating_Add (Toolbar.Right_X, Files.UI.Input_Field_Padding),
                 Click_X     => X));
      end if;

      Command := Files.UI.Toolbar_Command_At (X, Y, Width, Line_Height);
      if Command = Files.Commands.No_Command then
         Command := Files.UI.Bottom_Bar_Command_At (X, Y, Width, Height, Line_Height);
      end if;

      if Command /= Files.Commands.No_Command then
         return Command_Action (Command, Activate);
      end if;

      Item_Index := Files.Rendering.Item_At (Item_Layout, X, Y);
      if Item_Index /= 0 then
         if Snapshot.Rename_Active
           and then Item_Index <= Natural (Snapshot.Items.Length)
           and then Snapshot.Items.Element (Positive (Item_Index)).Selected
         then
            declare
               Item_Rect : constant Files.Rendering.Item_Layout :=
                 Item_Layout.Element (Positive (Item_Index));
            begin
               if Within (X, Item_Rect.Text_X, Item_Rect.Text_Width) then
                  return
                    Text_Click
                      (Files.Types.Focus_Rename_Input,
                       Cursor_At
                         (Text        => Snapshot.Rename_Text,
                          Text_X      => Item_Rect.Text_X,
                          Click_X     => X));
               end if;
            end;
         end if;

         return
           (Kind            => Item_Click_Input_Action,
            Command         => Files.Commands.No_Command,
            Direction       => Files.Types.Move_Right,
            Item_Index      => Item_Index,
            Root_Index      => 0,
            Result_Index    => 0,
            Scroll_Lines    => 0,
            Scroll_Area     => Scroll_Auto,
            Focus_Target    => Files.Types.Focus_None,
            Cursor_Position => 0,
            Settings_Field  => 0,
            Settings_Option => 0,
            Activate        => Activate,
            Toggle_Selection => Modifiers (Files.Types.Control_Key) and then not Modifiers (Files.Types.Shift_Key),
            Range_Selection  => Modifiers (Files.Types.Shift_Key));
      end if;

      return No_Action (Activate);
   end Translate_Click;

   function Translate_Scroll
     (Y_Offset : Integer)
      return Input_Action is
      Lines : constant Integer := Saturating_Negated_Triple (Y_Offset);
   begin
      if Y_Offset = 0 then
         return No_Action;
      end if;

      return Scroll_Action (Scroll_Auto, Lines);
   end Translate_Scroll;

   function Translate_Scroll_At
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Y_Offset    : Integer;
      Line_Height : Positive := 20)
      return Input_Action
   is
      Action  : Input_Action := Translate_Scroll (Y_Offset);
      Layout  : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Width, Height, Line_Height);
      Palette : constant Files.Rendering.Command_Palette_Layout :=
        Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height);
      Info    : constant Files.Rendering.Info_Pane_Layout :=
        Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height);

      function Within
        (Value  : Natural;
         Start  : Natural;
         Extent : Natural)
         return Boolean is
      begin
         return Extent > 0
           and then Value >= Start
           and then Value - Start < Extent;
      end Within;
   begin
      if Action.Kind /= Scroll_Input_Action then
         return Action;
      end if;

      if Snapshot.Command_Palette_Open then
         if Within (X, Palette.Results_X, Palette.Results_Width)
           and then Within (Y, Palette.Results_Y, Palette.Results_Height)
         then
            Action.Scroll_Area := Scroll_Command_Palette;
            return Action;
         end if;

         return No_Action;
      end if;

      if Snapshot.Root_Selector_Open or else Snapshot.Settings_Pane_Open then
         return No_Action;
      end if;

      if Snapshot.Info_Pane_Open
        and then Within (X, Info.X, Info.Width)
        and then Within (Y, Info.Y, Info.Height)
      then
         Action.Scroll_Area := Scroll_Info_Pane;
         return Action;
      end if;

      if Within (X, Layout.Main_X, Layout.Main_Width)
        and then Within (Y, Layout.Main_Y, Layout.Main_Height)
      then
         Action.Scroll_Area := Scroll_Main_View;
         return Action;
      end if;

      return No_Action;
   end Translate_Scroll_At;

end Files.Events;
