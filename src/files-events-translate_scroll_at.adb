with Files.Rendering.Layouts;
separate (Files.Events)
   function Translate_Scroll_At
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Y_Offset    : Integer;
      Line_Height : Positive)
      return Input_Action
   is
      Action  : Input_Action := Translate_Scroll (Y_Offset);
      Over_Tree   : Boolean;
      Tree_Action : Input_Action;
      --  Only the frame: each region's own layout is worked out in the branch
      --  that asks whether the wheel is over it, and only there.
      Layout  : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Layouts.Calculate_Layout (Snapshot, Width, Height, Line_Height);

      function Within
        (Value  : Natural;
         Start  : Natural;
         Extent : Natural)
         return Boolean renames Guikit.Layout.Within;

      --  One wheel step of a region bounded by Maximum, folding any stale
      --  offset beyond Maximum (after the window grows) into the event so the
      --  next step is never consumed by an invisible part of an old viewport.
      function Bounded_Scroll_Action
        (Target  : Scroll_Target;
         Raw     : Natural;
         Maximum : Natural)
         return Input_Action
      is
         Up         : constant Boolean := Action.Scroll_Lines < 0;
         Step       : constant Natural :=
           (if not Up then Natural (Action.Scroll_Lines)
            elsif Action.Scroll_Lines = Integer'First then Natural'Last
            else Natural (-Action.Scroll_Lines));
         Adjustment : constant Integer := Paged_Adjustment (Raw, Maximum, Step, Up);
      begin
         if Adjustment = 0 then
            return No_Action;
         end if;

         return Scroll_Action (Target, Adjustment);
      end Bounded_Scroll_Action;

      --  One wheel step of the main view: in rows when its rows are at least
      --  a line tall (Layouts.Main_View_Wheel_Lines), in lines otherwise,
      --  where a line step always moves a row.
      function Main_View_Scroll_Action
        (Main    : Files.Rendering.Layouts.Main_View_Layout;
         Raw     : Natural;
         Maximum : Natural)
         return Input_Action
      is
         Wanted : Natural;
      begin
         if Main.Row_Stride < Line_Height then
            return Bounded_Scroll_Action (Scroll_Main_View, Raw, Maximum);
         end if;
         Wanted := Files.Rendering.Layouts.Main_View_Wheel_Lines (Main, Line_Height, Maximum, Action.Scroll_Lines);
         if Wanted = Raw then
            return No_Action;
         end if;
         return Scroll_Action (Scroll_Main_View, Integer (Wanted) - Integer (Raw));
      end Main_View_Scroll_Action;

      --  The wheel over the open folder tree: Over is False, with no action,
      --  when it is elsewhere.
      procedure Tree_Scroll (Over : out Boolean; Result : out Input_Action) is
         Tree     : constant Files.Rendering.Layouts.Tree_Panel_Layout :=
           Files.Rendering.Layouts.Calculate_Tree_Panel_Layout (Snapshot, Layout, Line_Height);
         Count    : constant Natural := Natural (Snapshot.Tree_Rows.Length);
         Capacity : constant Natural :=
           Files.Rendering.Layouts.Tree_Row_Capacity (Snapshot, Tree);
      begin
         Over := Within (X, Tree.X, Tree.Width) and then Within (Y, Tree.Y, Tree.Height);
         Result :=
           (if not Over or else Count = 0 or else Capacity = 0 then No_Action
            else Bounded_Scroll_Action
                   (Scroll_Tree_Panel,
                    Snapshot.Tree_Panel_Scroll_Rows,
                    Files.Rendering.Layouts.Tree_Max_Scroll (Snapshot, Tree)));
      end Tree_Scroll;

      Position : constant Natural := Files.Rendering.Topmost_Overlay_Position (Snapshot);
   begin
      if Action.Kind /= Scroll_Input_Action then
         return Action;
      end if;

      --  The overlay on top (Files.UI_Types.Overlay_Stack, as clicks, keys and
      --  the drawing follow) takes the wheel: over its scrollable region it
      --  scrolls that, anywhere else the wheel is swallowed so nothing behind
      --  it moves.
      if Position /= 0 then
         case Files.UI_Types.Overlay_Stack (Position) is
            when Files.UI_Types.Command_Palette_Overlay =>
               declare
                  Palette : constant Files.Rendering.Layouts.Command_Palette_Layout :=
                    Files.Rendering.Layouts.Calculate_Command_Palette_Layout (Layout, Line_Height);
               begin
                  if Within (X, Palette.Results_X, Palette.Results_Width)
                    and then Within (Y, Palette.Results_Y, Palette.Results_Height)
                  then
                     Action.Scroll_Area := Scroll_Command_Palette;
                     return Action;
                  end if;
               end;
            when Files.UI_Types.Settings_Pane_Overlay =>
               declare
                  Settings_Pane : constant Guikit.Layout.Settings_Pane_Layout :=
                    Files.Rendering.Layouts.Settings_Pane_Region (Layout, Line_Height);
               begin
                  if Within (X, Settings_Pane.X, Settings_Pane.Width)
                    and then Within (Y, Settings_Pane.Y, Settings_Pane.Height)
                  then
                     Action.Scroll_Area := Scroll_Settings_Pane;
                     return Action;
                  end if;
               end;
            when Files.UI_Types.Tree_Pick_Overlay =>
               --  Picking a folder in the tree: only the tree scrolls.
               if Snapshot.Tree_Panel_Open then
                  Tree_Scroll (Over_Tree, Tree_Action);
                  if Over_Tree then
                     return Tree_Action;
                  end if;
               end if;
            --  No scrollable region of their own.
            when Files.UI_Types.Foreground_Job_Overlay
               | Files.UI_Types.Paste_Conflict_Overlay
               | Files.UI_Types.Root_Selector_Overlay
               | Files.UI_Types.Sort_Menu_Overlay
               | Files.UI_Types.Context_Menu_Overlay
               | Files.UI_Types.Label_Picker_Overlay
               | Files.UI_Types.Quick_Look_Overlay =>
               null;
         end case;
         return No_Action;
      end if;

      if Snapshot.Tree_Panel_Open then
         Tree_Scroll (Over_Tree, Tree_Action);
         if Over_Tree then
            return Tree_Action;
         end if;
      end if;

      if Snapshot.Info_Pane_Open then
         declare
            Info : constant Files.Rendering.Layouts.Info_Pane_Layout :=
              Files.Rendering.Layouts.Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height);
         begin
            if Within (X, Info.X, Info.Width) and then Within (Y, Info.Y, Info.Height) then
               return
                 Bounded_Scroll_Action
                   (Scroll_Info_Pane,
                    Snapshot.Info_Pane_Scroll_Lines,
                    Files.Rendering.Layouts.Info_Pane_Max_Scroll (Info, Line_Height));
            end if;
         end;
      end if;

      if Within (X, Layout.Main_X, Layout.Main_Width)
        and then Within (Y, Layout.Main_Y, Layout.Main_Height)
      then
         declare
            Main : constant Files.Rendering.Layouts.Main_View_Layout :=
              Files.Rendering.Layouts.Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
         begin
            return
              Main_View_Scroll_Action
                (Main,
                 Snapshot.Main_View_Scroll_Lines,
                 Files.Rendering.Layouts.Main_View_Max_Scroll (Main, Line_Height));
         end;
      end if;

      return No_Action;
   end Translate_Scroll_At;
