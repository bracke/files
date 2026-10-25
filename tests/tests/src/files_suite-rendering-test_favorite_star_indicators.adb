separate (Files_Suite.Rendering)
   procedure Test_Favorite_Star_Indicators (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Star glyphs are symbols emitted from source, not the catalog; rebuild
      --  their UTF-8 here so the assertions match what the frame carries.
      Filled_Star : constant String :=
        Character'Val (16#E2#) & Character'Val (16#98#) & Character'Val (16#85#);
      Toolbar : constant Guikit.Layout.Toolbar_Layout :=
        Guikit.Layout.Calculate_Toolbar_Layout (1000);

      function Count_Filled_Gold (Frame : Frame_Commands) return Natural is
         Total : Natural := 0;
      begin
         for Cmd of Frame.Text loop
            if To_String (Cmd.Text) = Filled_Star
              and then Cmd.Color = Guikit.Draw.Favorite_Star_Color
            then
               Total := Total + 1;
            end if;
         end loop;
         return Total;
      end Count_Filled_Gold;

      --  The path-bar favourite indicator is a drawn vector shape: a filled
      --  star (gold triangles) when favourited, an outline (muted triangles)
      --  when not. Detect it by colour within the star's band -- the top
      --  toolbar row at the very start of the path bar (Middle section).
      function Star_Triangle_Present
        (Frame : Frame_Commands;
         Color : Guikit.Draw.Render_Color)
         return Boolean
      is
         Left  : constant Float := Float (Toolbar.Middle_X);
         Right : constant Float := Float (Toolbar.Middle_X) + 80.0;
      begin
         for Tri of Frame.Triangles loop
            if Tri.Color = Color
              and then Tri.Y1 <= 45.0 and then Tri.Y2 <= 45.0 and then Tri.Y3 <= 45.0
              and then Tri.X1 >= Left and then Tri.X1 <= Right
            then
               return True;
            end if;
         end loop;
         return False;
      end Star_Triangle_Present;
   begin
      --  Grid indicator: exactly the favorited items carry a gold filled star.
      declare
         Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
         First    : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         First.Is_Favorite := True;
         Snapshot.Items.Replace_Element (1, First);
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Snapshot, 1000, 800, 20);
         begin
            Files_Suite.Support.Assert_Equal
              (Count_Filled_Gold (Frame),
               1,
               "one favorited grid item draws exactly one gold filled star");
         end;
      end;

      declare
         Snapshot : constant View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
         Frame    : constant Frame_Commands :=
           Build_Frame_Commands (Snapshot, 1000, 800, 20);
      begin
         Files_Suite.Support.Assert_Equal
           (Count_Filled_Gold (Frame),
            0,
            "no favorited items means no gold filled grid star in details view");
      end;

      --  Path-bar toggle: with no items in the view, the only star is the path
      --  star, so its filled/outline shape reflects the current-dir state.
      declare
         Fav      : View_Snapshot := Sample_Snapshot (0, Files.Types.Small_Icons);
      begin
         Fav.Current_Path := To_Unbounded_String ("/tmp/starred");
         Fav.Current_Path_Is_Favorite := True;
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Fav, 1000, 800, 20);
         begin
            Assert
              (Star_Triangle_Present (Frame, Guikit.Draw.Favorite_Star_Color),
               "a favorited current directory draws the filled path star");
            Assert
              (not Star_Triangle_Present (Frame, Guikit.Draw.Muted_Text_Color),
               "the favorited path bar does not also draw the empty outline star");
         end;
      end;

      declare
         Plain : View_Snapshot := Sample_Snapshot (0, Files.Types.Small_Icons);
      begin
         Plain.Current_Path := To_Unbounded_String ("/tmp/plain");
         Plain.Current_Path_Is_Favorite := False;
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Plain, 1000, 800, 20);
         begin
            Assert
              (Star_Triangle_Present (Frame, Guikit.Draw.Muted_Text_Color),
               "a non-favorited current directory draws the empty outline path star");
            Assert
              (not Star_Triangle_Present (Frame, Guikit.Draw.Favorite_Star_Color),
               "a non-favorited current directory draws no filled star");
         end;
      end;
   end Test_Favorite_Star_Indicators;
