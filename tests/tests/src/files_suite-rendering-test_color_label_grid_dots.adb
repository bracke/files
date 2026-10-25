separate (Files_Suite.Rendering)
   procedure Test_Color_Label_Grid_Dots (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      --  A labeled item emits a filled rectangle in its label color.
      declare
         Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
         First    : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         First.Label := Files.Types.Green;
         Snapshot.Items.Replace_Element (1, First);
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Snapshot, 1000, 800, 20);
         begin
            Assert
              (Has_Rectangle_Colored (Frame, Files.Rendering.Label_Render_Color (Files.Types.Green)),
               "a green-labeled item draws a green corner dot");
            Assert
              (not Has_Rectangle_Colored (Frame, Files.Rendering.Label_Render_Color (Files.Types.Red)),
               "the green-labeled item draws no red dot");
         end;
      end;

      --  An unlabeled grid draws no label dot in any label color.
      declare
         Snapshot : constant View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
         Frame    : constant Frame_Commands :=
           Build_Frame_Commands (Snapshot, 1000, 800, 20);
      begin
         Assert
           (not Has_Rectangle_Colored (Frame, Files.Rendering.Label_Render_Color (Files.Types.Green)),
            "an unlabeled grid draws no green dot");
         Assert
           (not Has_Rectangle_Colored (Frame, Files.Rendering.Label_Render_Color (Files.Types.Blue)),
            "an unlabeled grid draws no blue dot");
      end;

      --  Different labels resolve to different dot colors.
      declare
         Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
         First    : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         First.Label := Files.Types.Purple;
         Snapshot.Items.Replace_Element (1, First);
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Snapshot, 1000, 800, 20);
         begin
            Assert
              (Has_Rectangle_Colored (Frame, Files.Rendering.Label_Render_Color (Files.Types.Purple)),
               "a purple-labeled item draws a purple dot");
            Assert
              (Files.Rendering.Label_Render_Color (Files.Types.Purple)
                 /= Files.Rendering.Label_Render_Color (Files.Types.Green),
               "distinct labels resolve to distinct dot colors");
         end;
      end;
   end Test_Color_Label_Grid_Dots;
