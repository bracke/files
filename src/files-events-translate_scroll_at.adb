separate (Files.Events)
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
      Main    : constant Files.Rendering.Main_View_Layout :=
        Files.Rendering.Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
      Tree    : constant Files.Rendering.Tree_Panel_Layout :=
        Files.Rendering.Calculate_Tree_Panel_Layout (Snapshot, Layout, Line_Height);

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

      function Maximum_Line_Offset
        (Content_Height  : Natural;
         Viewport_Height : Natural;
         Scrollbar_Shown : Boolean)
         return Natural is
        (if Scrollbar_Shown
         then Files.Rendering.Max_Scroll_Lines (Content_Height, Viewport_Height, Line_Height)
         else 0);

      function Bounded_Scroll_Action
        (Target  : Scroll_Target;
         Raw     : Natural;
         Maximum : Natural)
         return Input_Action
      is
         Current   : constant Natural := Natural'Min (Raw, Maximum);
         Step      : Natural;
         Requested : Natural;
         Adjustment : Integer;
      begin
         if Action.Scroll_Lines < 0 then
            Step :=
              (if Action.Scroll_Lines = Integer'First
               then Natural'Last
               else Natural (-Action.Scroll_Lines));
            Requested := (if Step >= Current then 0 else Current - Step);
         else
            Step := Natural (Action.Scroll_Lines);
            Requested :=
              (if Step >= Maximum - Current
               then Maximum
               else Current + Step);
         end if;

         --  Raw can exceed Maximum after the window grows. Fold that stale
         --  offset into this event so the next wheel step is never consumed by
         --  an invisible part of the old, smaller viewport.
         Adjustment := Integer (Requested) - Integer (Raw);
         if Adjustment = 0 then
            return No_Action;
         end if;

         return Scroll_Action (Target, Adjustment);
      end Bounded_Scroll_Action;

      function Tree_Scroll_Action return Input_Action
      is
         Count    : constant Natural := Natural (Snapshot.Tree_Rows.Length);
         Capacity : constant Natural :=
           Files.Rendering.Tree_Row_Capacity (Snapshot, Tree);
         Maximum  : constant Natural :=
           (if Count > Capacity then Count - Capacity else 0);
      begin
         if Count = 0 or else Capacity = 0 then
            return No_Action;
         end if;

         return
           Bounded_Scroll_Action
             (Scroll_Tree_Panel,
              Snapshot.Tree_Panel_Scroll_Rows,
              Maximum);
      end Tree_Scroll_Action;

      --  These overlays own pointer input but do not currently expose a
      --  scrollable region.  Swallow the wheel event while one is open so it
      --  cannot move the main view or info pane behind the overlay.
      function Non_Scrolling_Overlay_Is_Open return Boolean is
        (Snapshot.Sort_Menu_Open
         or else Snapshot.Context_Menu_Open
         or else Snapshot.Tree_Pick_Active
         or else Snapshot.Paste_Conflict_Open
         or else Snapshot.Paste_Progress_Open
         or else Snapshot.Quick_Look_Open
         or else Snapshot.Label_Picker_Open);
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
            Settings_Pane : constant Guikit.Layout.Settings_Pane_Layout :=
              Guikit.Layout.Calculate_Settings_Pane_Layout
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

      if Snapshot.Tree_Pick_Active
        and then Snapshot.Tree_Panel_Open
        and then Within (X, Tree.X, Tree.Width)
        and then Within (Y, Tree.Y, Tree.Height)
      then
         return Tree_Scroll_Action;
      end if;

      if Non_Scrolling_Overlay_Is_Open then
         return No_Action;
      end if;

      if Snapshot.Tree_Panel_Open
        and then Within (X, Tree.X, Tree.Width)
        and then Within (Y, Tree.Y, Tree.Height)
      then
         return Tree_Scroll_Action;
      end if;

      if Snapshot.Info_Pane_Open
        and then Within (X, Info.X, Info.Width)
        and then Within (Y, Info.Y, Info.Height)
      then
         return
           Bounded_Scroll_Action
             (Scroll_Info_Pane,
              Snapshot.Info_Pane_Scroll_Lines,
              Maximum_Line_Offset
                (Info.Content_Height, Info.Height, Info.Scrollbar_Visible));
      end if;

      if Within (X, Layout.Main_X, Layout.Main_Width)
        and then Within (Y, Layout.Main_Y, Layout.Main_Height)
      then
         return
           Bounded_Scroll_Action
             (Scroll_Main_View,
              Snapshot.Main_View_Scroll_Lines,
              Maximum_Line_Offset
                (Main.Content_Height,
                 Main.Scrollbar_Track_Height,
                 Main.Scrollbar_Visible));
      end if;

      return No_Action;
   end Translate_Scroll_At;
