with Guikit.Layout;
separate (Files.Events)
   function Translate_Click
     (Snapshot    : Files.Rendering.View_Snapshot;
      Frame       : Files.Rendering.Frame_Commands;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Activate    : Boolean := False;
      Modifiers   : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Line_Height : Positive)
      return Input_Action
   is
      --  Only the cheap layouts every region shares are computed here; each
      --  region computes its costlier ones (item rectangles, root and tree
      --  rows, breadcrumbs) itself, so a click another region takes first
      --  never pays for them.
      Layout         : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Width, Height, Line_Height);
      Palette_Layout : constant Files.Rendering.Command_Palette_Layout :=
        Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height);
      Info_Pane      : constant Files.Rendering.Info_Pane_Layout :=
        Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height);
      Settings_Pane  : constant Guikit.Layout.Settings_Pane_Layout :=
        Guikit.Layout.Calculate_Settings_Pane_Layout (Width, Height, Layout.Toolbar_Height, Line_Height);
      Command        : Files.Commands.Command_Id := Files.Commands.No_Command;
      Item_Index     : Natural := 0;

      function Within
        (Value  : Natural;
         Start  : Natural;
         Extent : Natural)
         return Boolean renames Guikit.Layout.Within;

      --  Text_Width and Focused let a click on a focused, scrolled field
      --  (see Files.Rendering.Input_Scroll_Columns) land on the character
      --  drawn under it rather than one from the unscrolled text. Caret is
      --  the field's own caret, which a rename field of a multi-rename keeps
      --  per item rather than in the snapshot's single text cursor.
      function Cursor_At
        (Text        : Unbounded_String;
         Text_X      : Natural;
         Click_X     : Natural;
         Text_Width  : Natural := 0;
         Focused     : Boolean := False;
         Caret       : Natural := Snapshot.Text_Cursor_Position)
         return Natural
      is
         Char_W : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
         Raw    : constant String := To_String (Text);
         Scroll : constant Natural :=
           (if Focused
            then Files.Rendering.Input_Scroll_Columns (Raw, Caret, Text_Width, Line_Height)
            else 0);
         Click_Column : Natural;
      begin
         if Click_X <= Text_X then
            return Guikit.Utf8.Byte_Offset_For_Display_Column (Raw, Scroll);
         end if;

         Click_Column := Guikit.Layout.Saturating_Add (Click_X - Text_X, Char_W / 2) / Char_W;
         return Guikit.Utf8.Byte_Offset_For_Display_Column (Raw, Guikit.Layout.Saturating_Add (Click_Column, Scroll));
      end Cursor_At;

      function Text_Click
        (Target     : Files.Types.Focus_Target;
         Cursor     : Natural;
         Item_Index : Natural := 0)
         return Input_Action is
      begin
         return
           (Kind            => Text_Click_Input_Action,
            Field_Item      => Item_Index,
            Focus_Target    => Target,
            Cursor_Position => Cursor);
      end Text_Click;

      --  A press on a scrollbar: on the thumb it begins a drag, on the track
      --  above or below it it pages by Step towards the press.
      function Scroll_Click
        (Target       : Scroll_Target;
         Thumb_Y      : Natural;
         Thumb_Height : Natural;
         Step         : Natural;
         Raw          : Natural;
         Maximum      : Natural)
         return Input_Action
      is
         Adjustment : Integer;
      begin
         if Thumb_Height > 0
           and then Y >= Thumb_Y
           and then Y - Thumb_Y < Thumb_Height
         then
            return
              Scroll_Drag_Begin_Action
                (Target, Integer (Y) - Integer (Thumb_Y));
         end if;

         Adjustment := Paged_Adjustment (Raw, Maximum, Step, Up => Y < Thumb_Y);
         if Adjustment = 0 then
            return No_Action;
         end if;

         return Scroll_Action (Target, Adjustment);
      end Scroll_Click;

      --  Any click inside the open settings pane becomes a settings click
      --  carrying the coordinates; Guikit.Settings_Panel hit-tests it (focusing /
      --  toggling / choosing / stepping / pressing a button).
      function Settings_Click_Hit return Input_Action is
      begin
         if not Snapshot.Settings_Pane_Open
           or else not Within (X, Settings_Pane.X, Settings_Pane.Width)
           or else not Within (Y, Settings_Pane.Y, Settings_Pane.Height)
         then
            return No_Action;
         end if;
         return
           (Kind    => Settings_Click_Input_Action,
            Click_X => X,
            Click_Y => Y);
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
           (Kind      => Tree_Click_Input_Action,
            Tree_Node => Node_Index,
            Expander  => Toggle);
      end Tree_Action;

      --  Build a breadcrumb click action carrying the segment index.
      function Breadcrumb_Action
        (Segment_Index : Natural)
         return Input_Action is
      begin
         return
           (Kind          => Breadcrumb_Click_Input_Action,
            Segment_Index => Segment_Index);
      end Breadcrumb_Action;

      --  The click regions, front to back. Each sets Handled when the click is
      --  its own and Result is then the whole answer; a click none takes is
      --  no action.
      procedure Overlay_Click (Handled : out Boolean; Result : out Input_Action) is separate;
      procedure Sort_Menu_Click (Handled : out Boolean; Result : out Input_Action) is separate;
      procedure Tree_Panel_Click (Handled : out Boolean; Result : out Input_Action) is separate;
      procedure Info_Pane_Click (Handled : out Boolean; Result : out Input_Action) is separate;
      procedure Scrollbar_Click (Handled : out Boolean; Result : out Input_Action) is separate;
      procedure Toolbar_Click (Handled : out Boolean; Result : out Input_Action) is separate;
      procedure Main_View_Click (Handled : out Boolean; Result : out Input_Action) is separate;

      type Click_Region is access procedure (Handled : out Boolean; Result : out Input_Action);

      Regions : constant array (Positive range <>) of Click_Region :=
        [Overlay_Click'Access,
         Sort_Menu_Click'Access,
         Tree_Panel_Click'Access,
         Info_Pane_Click'Access,
         Scrollbar_Click'Access,
         Toolbar_Click'Access,
         Main_View_Click'Access];
   begin
      --  Window-system coordinates on the right/bottom edge can round to the
      --  framebuffer extent during scaling. They name no drawable pixel and
      --  must never activate a clipped control or dismiss a modal overlay.
      if Width = 0 or else Height = 0 or else X >= Width or else Y >= Height then
         return No_Action;
      end if;

      for Region of Regions loop
         declare
            Handled : Boolean;
            Result  : Input_Action;
         begin
            Region (Handled, Result);
            if Handled then
               return Result;
            end if;
         end;
      end loop;

      return No_Action;
   end Translate_Click;
