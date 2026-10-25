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
      Line_Height : Positive := 20)
      return Input_Action
   is
      Layout         : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Width, Height, Line_Height);
      Toolbar        : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Width);
      Toolbar_Input_Y : constant Natural := Guikit.Layout.Toolbar_Input_Y (Line_Height);
      Toolbar_Input_H : constant Natural := Guikit.Layout.Toolbar_Input_Height (Line_Height);
      Scope_Chip     : constant Guikit.Layout.Scope_Chip_Region :=
        Guikit.Layout.Filter_Scope_Chip_Region_Of
          (Toolbar, Files.UI.Filter_Scope_Chip_Width (Line_Height), Line_Height);
      Palette_Layout : constant Files.Rendering.Command_Palette_Layout :=
        Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line_Height);
      Main_View      : constant Files.Rendering.Main_View_Layout :=
        Files.Rendering.Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
      Info_Pane      : constant Files.Rendering.Info_Pane_Layout :=
        Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height);
      Root_Layout    : constant Files.Rendering.Root_Selector_Layout :=
        Files.Rendering.Calculate_Root_Selector_Layout (Snapshot, Layout, Line_Height);
      Root_Rows      : constant Files.Rendering.Root_Path_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Root_Path_Layout (Snapshot, Root_Layout);
      Settings_Pane  : constant Guikit.Layout.Settings_Pane_Layout :=
        Guikit.Layout.Calculate_Settings_Pane_Layout (Width, Height, Layout.Toolbar_Height, Line_Height);
      Item_Layout    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height);
      Breadcrumb_Rows : constant Files.Rendering.Breadcrumb_Segment_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Breadcrumb_Layout (Snapshot, Width, Line_Height);
      Path_Star      : constant Files.Rendering.Path_Favorite_Star_Bounds :=
        Files.Rendering.Path_Favorite_Star_Region (Width, Line_Height);
      Tree_Panel_L   : constant Files.Rendering.Tree_Panel_Layout :=
        Files.Rendering.Calculate_Tree_Panel_Layout (Snapshot, Layout, Line_Height);
      Tree_Rows_L    : constant Files.Rendering.Tree_Row_Layout_Vectors.Vector :=
        Files.Rendering.Calculate_Tree_Row_Layout (Snapshot, Tree_Panel_L, Line_Height);
      Tree_Page_Rows : constant Natural :=
        Files.Rendering.Tree_Row_Capacity (Snapshot, Tree_Panel_L);
      Root_Index     : constant Natural := Files.Rendering.Hit.Root_Path_At (Root_Rows, X, Y);
      Breadcrumb_Index    : constant Natural := Files.Rendering.Hit.Breadcrumb_At (Breadcrumb_Rows, X, Y);
      Tree_Triangle_Index : constant Natural := Files.Rendering.Hit.Tree_Triangle_At (Tree_Rows_L, X, Y);
      Tree_Node_Index     : constant Natural := Files.Rendering.Hit.Tree_Row_At (Tree_Rows_L, X, Y);
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

      function Saturating_Add
        (Left  : Natural;
         Right : Natural)
         return Natural
        renames Guikit.Layout.Saturating_Add;

      function Saturating_Multiply
        (Value  : Natural;
         Factor : Natural)
         return Natural
        renames Guikit.Layout.Saturating_Multiply;

      --  Text_Width and Focused let a click on a focused, scrolled field
      --  (see Files.Rendering.Input_Scroll_Columns) land on the character
      --  drawn under it rather than one from the unscrolled text.
      function Cursor_At
        (Text        : Unbounded_String;
         Text_X      : Natural;
         Click_X     : Natural;
         Text_Width  : Natural := 0;
         Focused     : Boolean := False)
         return Natural
      is
         Char_W : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
         Raw    : constant String := To_String (Text);
         Scroll : constant Natural :=
           (if Focused
            then Files.Rendering.Input_Scroll_Columns
                   (Raw, Snapshot.Text_Cursor_Position, Text_Width, Line_Height)
            else 0);
         Click_Column : Natural;
      begin
         if Click_X <= Text_X then
            return Files.UTF8.Byte_Offset_For_Display_Column (Raw, Scroll);
         end if;

         Click_Column := Saturating_Add (Click_X - Text_X, Char_W / 2) / Char_W;
         return Files.UTF8.Byte_Offset_For_Display_Column (Raw, Saturating_Add (Click_Column, Scroll));
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
            Direction       => Guikit.Input.Move_Right,
            Item_Index      => Item_Index,
            Root_Index      => 0,
            Result_Index    => 0,
            Click_X          => 0,
            Click_Y          => 0,
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
        (Target       : Scroll_Target;
         Thumb_Y      : Natural;
         Thumb_Height : Natural;
         Y_Pos        : Natural;
         Step         : Positive;
         Raw          : Natural;
         Maximum      : Natural)
         return Input_Action
      is
         Current    : constant Natural := Natural'Min (Raw, Maximum);
         Requested  : Natural;
         Adjustment : Integer;
      begin
         if Thumb_Height > 0
           and then Y_Pos >= Thumb_Y
           and then Y_Pos - Thumb_Y < Thumb_Height
         then
            return
              Scroll_Drag_Begin_Action
                (Target, Integer (Y_Pos) - Integer (Thumb_Y), Activate);
         end if;

         if Y_Pos < Thumb_Y then
            Requested := (if Step >= Current then 0 else Current - Step);
         else
            Requested :=
              (if Step >= Maximum - Current
               then Maximum
               else Current + Step);
         end if;

         --  Raw may exceed Maximum after a resize. Include that stale excess in
         --  the exact adjustment so a page click cannot preserve hidden scroll.
         Adjustment := Integer (Requested) - Integer (Raw);
         if Adjustment = 0 then
            return No_Action (Activate);
         end if;

         return Scroll_Action (Target, Adjustment, Activate);
      end Scroll_Click;

      function Maximum_Line_Offset
        (Content_Height  : Natural;
         Viewport_Height : Natural;
         Scrollbar_Shown : Boolean)
         return Natural is
        (if Scrollbar_Shown
         then Files.Rendering.Max_Scroll_Lines (Content_Height, Viewport_Height, Line_Height)
         else 0);

      function Tree_Scroll_Click return Input_Action
      is
         Count    : constant Natural := Natural (Snapshot.Tree_Rows.Length);
         Maximum  : constant Natural :=
           (if Count > Tree_Page_Rows then Count - Tree_Page_Rows else 0);
         Raw      : constant Natural := Snapshot.Tree_Panel_Scroll_Rows;
         Current  : constant Natural := Natural'Min (Raw, Maximum);
         Requested : Natural;
         Adjustment : Integer;
      begin
         if Tree_Panel_L.Scrollbar_Height > 0
           and then Y >= Tree_Panel_L.Scrollbar_Thumb_Y
           and then Y - Tree_Panel_L.Scrollbar_Thumb_Y
             < Tree_Panel_L.Scrollbar_Height
         then
            return
              Scroll_Drag_Begin_Action
                (Scroll_Tree_Panel,
                 Integer (Y) - Integer (Tree_Panel_L.Scrollbar_Thumb_Y),
                 Activate);
         elsif Tree_Page_Rows = 0 or else Count = 0 then
            return No_Action (Activate);
         elsif Y < Tree_Panel_L.Scrollbar_Thumb_Y then
            Requested :=
              (if Tree_Page_Rows >= Current
               then 0
               else Current - Tree_Page_Rows);
         else
            Requested :=
              (if Tree_Page_Rows >= Maximum - Current
               then Maximum
               else Current + Tree_Page_Rows);
         end if;

         --  Raw may be stale after a resize. Include its excess in the exact
         --  adjustment so a track click cannot leave an invisible offset.
         Adjustment := Integer (Requested) - Integer (Raw);
         if Adjustment = 0 then
            return No_Action (Activate);
         end if;

         return Scroll_Action (Scroll_Tree_Panel, Adjustment, Activate);
      end Tree_Scroll_Click;

      --  Any click inside the open settings pane becomes a settings click
      --  carrying the coordinates; Guikit.Settings_Panel hit-tests it (focusing /
      --  toggling / choosing / stepping / pressing a button).
      function Settings_Click_Hit return Input_Action is
         Pane : constant Guikit.Layout.Settings_Pane_Layout :=
           Guikit.Layout.Calculate_Settings_Pane_Layout (Width, Height, Layout.Toolbar_Height, Line_Height);
      begin
         if not Snapshot.Settings_Pane_Open
           or else not Within (X, Pane.X, Pane.Width)
           or else not Within (Y, Pane.Y, Pane.Height)
         then
            return No_Action (Activate);
         end if;
         return
           (Kind         => Settings_Click_Input_Action,
            Click_X      => X,
            Click_Y      => Y,
            Focus_Target => Files.Types.Focus_Settings_Input,
            Activate     => Activate,
            others       => <>);
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
            Direction        => Guikit.Input.Move_Right,
            Item_Index       => Node_Index,
            Root_Index       => 0,
            Result_Index     => 0,
            Click_X          => 0,
            Click_Y          => 0,
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
            Direction        => Guikit.Input.Move_Right,
            Item_Index       => Segment_Index,
            Root_Index       => 0,
            Result_Index     => 0,
            Click_X          => 0,
            Click_Y          => 0,
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
         return No_Action (Activate);
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

      return No_Action (Activate);
   end Translate_Click;
