separate (Files_Suite.Rendering)
   --  The column dividers span the visible rows only: they stop at the bottom of
   --  the last on-screen row, never descending past it into empty space below the
   --  list or through the bottom bar.
   procedure Test_Detail_Separators_Within_Content (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  Bottom edge (Y + Height) of the tallest column divider, or 0 when none.
      --  Dividers are 1px, border-coloured, and begin at the content top (just
      --  inside the main region), which distinguishes them from the bottom-bar
      --  borders far below.
      function Max_Divider_Bottom
        (Frame : Frame_Commands; Layout : Guikit.Draw.Layout_Metrics) return Natural
      is
         Result : Natural := 0;
      begin
         for Rect of Frame.Rectangles loop
            if Rect.Width = 1 and then Rect.Color = Border_Color
              and then Rect.Y >= Layout.Main_Y and then Rect.Y < Layout.Main_Y + 20
            then
               Result := Natural'Max (Result, Rect.Y + Rect.Height);
            end if;
         end loop;
         return Result;
      end Max_Divider_Bottom;
   begin
      --  Overflow: the last row is off-screen, yet the dividers stop within the
      --  content, never running into the bottom bar.
      declare
         Snapshot : constant View_Snapshot := Sample_Snapshot (40, Files.Types.Details);
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
         Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
         Bottom   : constant Natural := Max_Divider_Bottom (Frame, Layout);
      begin
         Assert (Bottom > Layout.Main_Y, "the overflowing details view emits column dividers");
         Assert (Bottom <= Layout.Main_Y + Layout.Main_Height,
                 "dividers stay within the content area, not into the bottom bar");
      end;

      --  Short list: the dividers stop exactly at the last visible row's bottom,
      --  well above the content bottom -- not filling the empty space below.
      declare
         Snapshot : constant View_Snapshot := Sample_Snapshot (3, Files.Types.Details);
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
         Items    : constant Item_Layout_Vectors.Vector :=
           Calculate_Item_Layout (Snapshot, Layout, 20);
         Last     : constant Item_Layout := Items.Element (Items.Last_Index);
         Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
         Bottom   : constant Natural := Max_Divider_Bottom (Frame, Layout);
      begin
         Files_Suite.Support.Assert_Equal
           (Bottom,
            Last.Y + Last.Height,
            "the divider stops exactly at the last visible row's bottom");
         Assert (Bottom < Layout.Main_Y + Layout.Main_Height,
                 "a short list leaves the dividers well above the content bottom");
      end;
   end Test_Detail_Separators_Within_Content;
