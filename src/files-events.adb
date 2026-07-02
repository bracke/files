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
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
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
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end Command_Action;

   function Conflict_Action
     (Button   : Natural;
      Activate : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind            => Conflict_Click_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => Files.Types.Move_Right,
         Item_Index      => 0,
         Root_Index      => 0,
         Result_Index    => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => Button,
         Settings_Option => 0,
         Activate        => Activate,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end Conflict_Action;

   function Paste_Cancel_Action
     (Activate : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind            => Paste_Cancel_Input_Action,
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
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end Paste_Cancel_Action;

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
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
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
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end Scroll_Action;

   function Scroll_Drag_Begin_Action
     (Target   : Scroll_Target;
      Anchor   : Integer;
      Activate : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind             => Scrollbar_Drag_Begin_Input_Action,
         Command          => Files.Commands.No_Command,
         Direction        => Files.Types.Move_Down,
         Item_Index       => 0,
         Root_Index       => 0,
         Result_Index     => 0,
         Scroll_Lines     => 0,
         Scroll_Area      => Target,
         Focus_Target     => Files.Types.Focus_None,
         Cursor_Position  => 0,
         Settings_Field   => 0,
         Settings_Option  => 0,
         Activate         => Activate,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => Anchor);
   end Scroll_Drag_Begin_Action;

   --  Build a details-header column-resize drag-begin action. The target column,
   --  the separator's origin x edge, and the column's effective width at drag
   --  start are packed into the shared Item_Index, Cursor_Position, and
   --  Scroll_Drag_Anchor fields (see the Input_Action record comment). The
   --  desktop shell owns the continuous drag, mirroring the scrollbar drag.
   --
   --  @param Column Optional detail column the drag resizes.
   --  @param Origin_X Separator's x edge at drag start.
   --  @param Origin_Width Column's effective width at drag start.
   --  @return Column-resize drag-begin input action.
   function Column_Resize_Begin_Action
     (Column       : Files.Types.Optional_Detail_Column;
      Origin_X     : Natural;
      Origin_Width : Natural)
      return Input_Action is
   begin
      return
        (Kind            => Column_Resize_Begin_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => Files.Types.Move_Right,
         Item_Index      => Files.Types.Detail_Column'Pos (Column),
         Root_Index      => 0,
         Result_Index    => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => Origin_X,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => False,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => Origin_Width);
   end Column_Resize_Begin_Action;

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

      if Modifiers = Files.Types.No_Modifiers
        or else
          (Modifiers (Files.Types.Shift_Key)
           and then not Modifiers (Files.Types.Control_Key)
           and then not Modifiers (Files.Types.Alt_Key)
           and then not Modifiers (Files.Types.Meta_Key))
      then
         case Key is
            when Files.Types.Key_Left =>
               return
                 (Kind            => Selection_Input_Action,
                  Direction       => Files.Types.Move_Left,
                  Range_Selection => Modifiers (Files.Types.Shift_Key),
                  others          => <>);
            when Files.Types.Key_Right =>
               return
                 (Kind            => Selection_Input_Action,
                  Direction       => Files.Types.Move_Right,
                  Range_Selection => Modifiers (Files.Types.Shift_Key),
                  others          => <>);
            when Files.Types.Key_Up =>
               return
                 (Kind            => Selection_Input_Action,
                  Direction       => Files.Types.Move_Up,
                  Range_Selection => Modifiers (Files.Types.Shift_Key),
                  others          => <>);
            when Files.Types.Key_Down =>
               return
                 (Kind            => Selection_Input_Action,
                  Direction       => Files.Types.Move_Down,
                  Range_Selection => Modifiers (Files.Types.Shift_Key),
                  others          => <>);
            when others =>
               null;
         end case;
      end if;

      return No_Action;
   end Translate_Key;

   function Translate_Click
     (Snapshot    : Files.Rendering.View_Snapshot;
      Frame       : Files.Rendering.Frame_Commands;
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
      Settings_Pane  : constant Files.UI.Settings_Pane_Layout :=
        Files.UI.Calculate_Settings_Pane_Layout (Width, Height, Layout.Toolbar_Height, Line_Height);
      Item_Layout    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height);
      Breadcrumb_Rows : constant Files.Rendering.Breadcrumb_Segment_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Breadcrumb_Layout (Snapshot, Width, Line_Height);
      Tree_Panel_L   : constant Files.Rendering.Tree_Panel_Layout :=
        Files.Rendering.Calculate_Tree_Panel_Layout (Snapshot, Layout, Line_Height);
      Tree_Rows_L    : constant Files.Rendering.Tree_Row_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Tree_Row_Layout (Snapshot, Tree_Panel_L, Line_Height);
      Result_Index   : constant Natural := Files.Rendering.Command_Result_At (Palette_Rows, X, Y);
      Root_Index     : constant Natural := Files.Rendering.Root_Path_At (Root_Rows, X, Y);
      Breadcrumb_Index    : constant Natural := Files.Rendering.Breadcrumb_At (Breadcrumb_Rows, X, Y);
      Tree_Triangle_Index : constant Natural := Files.Rendering.Tree_Triangle_At (Tree_Rows_L, X, Y);
      Tree_Node_Index     : constant Natural := Files.Rendering.Tree_Row_At (Tree_Rows_L, X, Y);
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

         return Available_Height / Row_Height;
      end Visible_Row_Count;

      function Cursor_At
        (Text        : Unbounded_String;
         Text_X      : Natural;
         Click_X     : Natural)
         return Natural
      is
         Char_W : constant Positive := Files.UI.Caret_Advance_Width (Line_Height);
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
        (Target     : Files.Types.Focus_Target;
         Cursor     : Natural;
         Item_Index : Natural := 0)
         return Input_Action is
      begin
         return
           (Kind            => Text_Click_Input_Action,
            Command         => Files.Commands.No_Command,
            Direction       => Files.Types.Move_Right,
            Item_Index      => Item_Index,
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
            Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
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
            return
              Scroll_Drag_Begin_Action
                (Target, Integer (Y_Pos) - Integer (Thumb_Y), Activate);
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
            Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
      end Settings_Click;

      function Settings_Click_Hit return Input_Action is
         Pane : constant Files.UI.Settings_Pane_Layout :=
           Files.UI.Calculate_Settings_Pane_Layout (Width, Height, Layout.Toolbar_Height, Line_Height);
         Hit  : constant Files.Rendering.Settings_Hit_Region :=
           Files.Rendering.Settings_Hit_At (Frame, X, Y);
         use type Files.Rendering.Settings_Hit_Kind;
      begin
         if not Snapshot.Settings_Pane_Open
           or else not Within (X, Pane.X, Pane.Width)
           or else not Within (Y, Pane.Y, Pane.Height)
         then
            return No_Action (Activate);
         end if;

         case Hit.Kind is
            when Files.Rendering.Settings_Hit_Field =>
               return Settings_Click (Hit.Field);
            when Files.Rendering.Settings_Hit_Reset =>
               if Snapshot.Settings_Can_Reset then
                  return Command_Action (Files.Commands.Reset_Settings_Command, Activate);
               end if;
            when Files.Rendering.Settings_Hit_Segment =>
               if Hit.Field /= 0 and then Hit.Option /= 0 then
                  return Settings_Click (Hit.Field, Hit.Option);
               end if;
            when Files.Rendering.Settings_Hit_Toggle =>
               if Hit.Field /= 0 and then Hit.Option /= 0 then
                  return Settings_Click (Hit.Field, Hit.Option);
               end if;
            when Files.Rendering.Settings_Hit_Stepper_Down =>
               if Hit.Field /= 0 then
                  return Settings_Click (Hit.Field, 150);
               end if;
            when Files.Rendering.Settings_Hit_Stepper_Up =>
               if Hit.Field /= 0 then
                  return Settings_Click (Hit.Field, 151);
               end if;
            when Files.Rendering.Settings_Hit_Add =>
               if Hit.Field /= 0 then
                  return Settings_Click (Hit.Field, 100);
               end if;
            when Files.Rendering.Settings_Hit_Remove =>
               if Hit.Field /= 0 then
                  return Settings_Click (Hit.Field, 101);
               end if;
            when Files.Rendering.Settings_Hit_None =>
               null;
         end case;

         return No_Action (Activate);
      end Settings_Click_Hit;

      --  A click on an overlay panel's top-right close (X) button. The button
      --  geometry comes from Files.Rendering.Panel_Close_Button so it matches
      --  what Build_Frame_Commands drew exactly (rule: coordinates from layout).
      function Close_Button_Hit
        (Panel_X : Natural;
         Panel_Y : Natural;
         Panel_W : Natural;
         Panel_H : Natural)
         return Boolean
      is
         Btn : constant Files.Rendering.Close_Button_Layout :=
           Files.Rendering.Panel_Close_Button (Panel_X, Panel_Y, Panel_W, Panel_H, Line_Height);
      begin
         return Btn.Visible
           and then Within (X, Btn.X, Btn.Width)
           and then Within (Y, Btn.Y, Btn.Height);
      end Close_Button_Hit;

      --  Build a folder-tree click action carrying the node index; Toggle marks
      --  an expander-triangle click (expand/collapse) versus a label click.
      function Tree_Action
        (Node_Index : Natural;
         Toggle     : Boolean)
         return Input_Action is
      begin
         return
           (Kind             => Tree_Click_Input_Action,
            Command          => Files.Commands.No_Command,
            Direction        => Files.Types.Move_Right,
            Item_Index       => Node_Index,
            Root_Index       => 0,
            Result_Index     => 0,
            Scroll_Lines     => 0,
            Scroll_Area      => Scroll_Auto,
            Focus_Target     => Files.Types.Focus_None,
            Cursor_Position  => 0,
            Settings_Field   => 0,
            Settings_Option  => 0,
            Activate         => Activate,
            Toggle_Selection => Toggle,
            Range_Selection  => False,
            Scroll_Drag_Anchor => 0);
      end Tree_Action;

      --  Build a breadcrumb click action carrying the segment index.
      function Breadcrumb_Action
        (Segment_Index : Natural)
         return Input_Action is
      begin
         return
           (Kind             => Breadcrumb_Click_Input_Action,
            Command          => Files.Commands.No_Command,
            Direction        => Files.Types.Move_Right,
            Item_Index       => Segment_Index,
            Root_Index       => 0,
            Result_Index     => 0,
            Scroll_Lines     => 0,
            Scroll_Area      => Scroll_Auto,
            Focus_Target     => Files.Types.Focus_None,
            Cursor_Position  => 0,
            Settings_Field   => 0,
            Settings_Option  => 0,
            Activate         => Activate,
            Toggle_Selection => False,
            Range_Selection  => False,
            Scroll_Drag_Anchor => 0);
      end Breadcrumb_Action;
   begin
      --  The paste-progress overlay is a modal-lite top-most panel: while a long
      --  copy/move runs, a click either hits its Cancel button or is swallowed so
      --  nothing behind it reacts.
      if Snapshot.Paste_Progress_Open then
         declare
            use type Files.Rendering.Conflict_Hit_Kind;
            Hit : constant Files.Rendering.Conflict_Hit_Region :=
              Files.Rendering.Conflict_Hit_At (Frame, X, Y);
         begin
            if Hit.Kind = Files.Rendering.Conflict_Hit_Progress_Cancel then
               return Paste_Cancel_Action (Activate);
            end if;
            return No_Action (Activate);
         end;
      end if;

      --  The paste-conflict dialog is a top-most modal: while it is open it
      --  consumes every click, either resolving to one of its controls or being
      --  swallowed so nothing behind it reacts.
      if Snapshot.Paste_Conflict_Open then
         declare
            use type Files.Rendering.Conflict_Hit_Kind;
            Hit    : constant Files.Rendering.Conflict_Hit_Region :=
              Files.Rendering.Conflict_Hit_At (Frame, X, Y);
            Dialog : constant Files.Rendering.Conflict_Dialog_Layout :=
              Files.Rendering.Calculate_Conflict_Dialog_Layout (Snapshot, Layout, Line_Height);
         begin
            case Hit.Kind is
               when Files.Rendering.Conflict_Hit_Replace =>
                  return Conflict_Action (Conflict_Button_Replace, Activate);
               when Files.Rendering.Conflict_Hit_Skip =>
                  return Conflict_Action (Conflict_Button_Skip, Activate);
               when Files.Rendering.Conflict_Hit_Rename =>
                  return Conflict_Action (Conflict_Button_Rename, Activate);
               when Files.Rendering.Conflict_Hit_Cancel =>
                  return Conflict_Action (Conflict_Button_Cancel, Activate);
               when Files.Rendering.Conflict_Hit_Apply_All =>
                  return Conflict_Action (Conflict_Button_Apply_All, Activate);
               when Files.Rendering.Conflict_Hit_None
                  | Files.Rendering.Conflict_Hit_Progress_Cancel =>
                  if Close_Button_Hit (Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height) then
                     return Conflict_Action (Conflict_Button_Cancel, Activate);
                  end if;
                  return No_Action (Activate);
            end case;
         end;
      end if;

      --  Route a close-button click through the same command Escape uses for
      --  each panel, before the panel body/scrollbar hit-tests below consume it.
      if Snapshot.Command_Palette_Open
        and then Close_Button_Hit
          (Palette_Layout.X, Palette_Layout.Y, Palette_Layout.Width, Palette_Layout.Height)
      then
         return Command_Action (Files.Commands.Close_Command_Palette_Command, Activate);
      elsif Snapshot.Settings_Pane_Open
        and then Close_Button_Hit
          (Settings_Pane.X, Settings_Pane.Y, Settings_Pane.Width, Settings_Pane.Height)
      then
         return Command_Action (Files.Commands.Toggle_Settings_Pane_Command, Activate);
      elsif Snapshot.Root_Selector_Open
        and then Close_Button_Hit
          (Root_Layout.X, Root_Layout.Y, Root_Layout.Width, Root_Layout.Height)
      then
         return Command_Action (Files.Commands.Close_Command_Palette_Command, Activate);
      elsif Snapshot.Tree_Panel_Open
        and then Close_Button_Hit
          (Tree_Panel_L.X, Tree_Panel_L.Y, Tree_Panel_L.Width, Tree_Panel_L.Height)
      then
         return Command_Action (Files.Commands.Toggle_Folder_Tree_Command, Activate);
      elsif Snapshot.Info_Pane_Open
        and then Close_Button_Hit
          (Info_Pane.X,
           Info_Pane.Y,
           (if Info_Pane.Scrollbar_Visible and then Info_Pane.Width > Info_Pane.Scrollbar_Width
            then Info_Pane.Width - Info_Pane.Scrollbar_Width
            else Info_Pane.Width),
           Info_Pane.Height)
      then
         return Command_Action (Files.Commands.Toggle_Info_Pane_Command, Activate);
      end if;

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
            Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
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
            Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
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

      if Snapshot.Tree_Panel_Open then
         if Tree_Triangle_Index /= 0 then
            return Tree_Action (Tree_Triangle_Index, Toggle => True);
         elsif Tree_Node_Index /= 0 then
            return Tree_Action (Tree_Node_Index, Toggle => False);
         elsif Within (X, Tree_Panel_L.X, Tree_Panel_L.Width)
           and then Within (Y, Tree_Panel_L.Y, Tree_Panel_L.Height)
         then
            --  Consume clicks on the tree panel chrome so they do not fall
            --  through to items drawn behind the sidebar.
            return No_Action (Activate);
         end if;
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

      if Snapshot.Info_Pane_Open and then Snapshot.Permissions_Editable then
         declare
            Cell : constant Files.Rendering.Permission_Hit_Region :=
              Files.Rendering.Permission_Hit_At (Frame, X, Y);
         begin
            if Cell.Present then
               return
                 (Kind       => Permission_Toggle_Input_Action,
                  Item_Index => Cell.Bit,
                  others     => <>);
            end if;
         end;
      end if;

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

      if Breadcrumb_Index /= 0 then
         return Breadcrumb_Action (Breadcrumb_Index);
      elsif Within (X, Toolbar.Middle_X, Toolbar.Middle_Width)
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

      if Snapshot.Sort_Menu_Open then
         Command := Files.UI.Bottom_Bar_Sort_Menu_Command_At (X, Y, Width, Height, Line_Height);
         if Command /= Files.Commands.No_Command then
            return Command_Action (Command, Activate);
         elsif Files.UI.Bottom_Bar_Sort_Menu_Contains (X, Y, Width, Height, Line_Height) then
            --  Click inside the open menu's rectangle but not on a row (its
            --  padding bands): consume it so it cannot fall through and select
            --  the item drawn underneath the menu.
            return No_Action (Activate);
         end if;
      end if;

      Command := Files.UI.Toolbar_Command_At (X, Y, Width, Line_Height);
      if Command = Files.Commands.No_Command then
         Command := Files.UI.Bottom_Bar_Command_At (X, Y, Width, Height, Line_Height);
      end if;

      if Command /= Files.Commands.No_Command then
         return Command_Action (Command, Activate);
      end if;

      --  A press on a header separator begins a column resize and takes
      --  precedence over the sort click on the header cell behind it.
      declare
         Separator : constant Files.Rendering.Detail_Column_Separator :=
           Files.Rendering.Details_Header_Separator_At (Snapshot, Layout, X, Y, Line_Height);
      begin
         if Separator.Present then
            return
              Column_Resize_Begin_Action
                (Separator.Column, Separator.Origin_X, Separator.Width);
         end if;
      end;

      Command := Files.Rendering.Details_Header_Command_At (Snapshot, Layout, X, Y, Line_Height);
      if Command /= Files.Commands.No_Command then
         return Command_Action (Command, Activate);
      end if;

      Item_Index := Files.Rendering.Item_At (Item_Layout, X, Y);
      if Item_Index /= 0 then
         if Snapshot.Rename_Active
           and then Item_Index <= Natural (Snapshot.Items.Length)
           and then Snapshot.Items.Element (Positive (Item_Index)).Renaming
         then
            declare
               Item_Rect : constant Files.Rendering.Item_Layout :=
                 Item_Layout.Element (Positive (Item_Index));
               Snapshot_Item : constant Files.Rendering.Item_Snapshot :=
                 Snapshot.Items.Element (Positive (Item_Index));
               Field_X : Natural;
               Field_W : Natural;
            begin
               Files.Rendering.Rename_Field_Extent
                 (Item      => Item_Rect,
                  View_Mode => Snapshot.View_Mode,
                  Renaming  => True,
                  Field_X   => Field_X,
                  Field_W   => Field_W);
               if Within (X, Field_X, Field_W) then
                  return
                    Text_Click
                      (Files.Types.Focus_Rename_Input,
                       Cursor_At
                         (Text        => Snapshot_Item.Rename_Value,
                          Text_X      => Field_X,
                          Click_X     => X),
                       Item_Index);
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
            Range_Selection  => Modifiers (Files.Types.Shift_Key),
            Scroll_Drag_Anchor => 0);
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

      if Snapshot.Root_Selector_Open then
         return No_Action;
      end if;

      if Snapshot.Settings_Pane_Open then
         declare
            Settings_Pane : constant Files.UI.Settings_Pane_Layout :=
              Files.UI.Calculate_Settings_Pane_Layout
                (Width, Height, Layout.Toolbar_Height, Line_Height);
         begin
            if Within (X, Settings_Pane.X, Settings_Pane.Width)
              and then Within (Y, Settings_Pane.Y, Settings_Pane.Height)
            then
               Action.Scroll_Area := Scroll_Settings_Pane;
               return Action;
            end if;
         end;
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
