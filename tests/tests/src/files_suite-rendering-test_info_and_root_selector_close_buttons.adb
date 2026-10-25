separate (Files_Suite.Rendering)
   procedure Test_Info_And_Root_Selector_Close_Buttons (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
   begin
      --  Info pane.
      declare
         Snap    : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout  : Guikit.Draw.Layout_Metrics;
         Info    : Info_Pane_Layout;
         Panel_W : Natural;
         Close   : Close_Button_Layout;
         Frame   : Frame_Commands;
      begin
         Snap.Info_Pane_Open := True;
         Layout  := Calculate_Layout (Snap, Width, Height, LH);
         Info    := Calculate_Info_Pane_Layout (Snap, Layout, LH);
         Panel_W :=
           (if Info.Scrollbar_Visible and then Info.Width > Info.Scrollbar_Width
            then Info.Width - Info.Scrollbar_Width
            else Info.Width);
         Close   := Panel_Close_Button (Info.X, Info.Y, Panel_W, Info.Height, LH);
         Frame   := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the info pane hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open info pane emits a close-button accessibility node");
      end;

      --  Root selector.
      declare
         Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout : Guikit.Draw.Layout_Metrics;
         Root   : Root_Selector_Layout;
         Close  : Close_Button_Layout;
         Frame  : Frame_Commands;
      begin
         Snap.Root_Selector_Open := True;
         for Index in 1 .. 3 loop
            Snap.Root_Paths.Append (To_Unbounded_String ("/root" & Integer'Image (Index)));
            Snap.Root_Labels.Append (To_Unbounded_String ("Root" & Integer'Image (Index)));
         end loop;
         Layout := Calculate_Layout (Snap, Width, Height, LH);
         Root   := Calculate_Root_Selector_Layout (Snap, Layout, LH);
         Close  := Panel_Close_Button (Root.X, Root.Y, Root.Width, Root.Height, LH);
         Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the root selector hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open root selector emits a close-button accessibility node");
         declare
            Compact_Layout : constant Guikit.Draw.Layout_Metrics :=
              Calculate_Layout (Snap, 12, 200, LH);
            Compact_Root : constant Root_Selector_Layout :=
              Calculate_Root_Selector_Layout (Snap, Compact_Layout, LH);
            Compact_Rows : constant Root_Path_Layout_Vectors.Vector :=
              Calculate_Root_Path_Layout (Snap, Compact_Root);
         begin
            Assert (not Compact_Rows.Is_Empty, "the compact root selector retains a visible row");
            for Row of Compact_Rows loop
               Assert
                 (Row.X >= Compact_Root.X
                  and then Row.X + Row.Width <= Compact_Root.X + Compact_Root.Width,
                  "compact root rows stay within the selector width");
            end loop;
         end;
      end;
   end Test_Info_And_Root_Selector_Close_Buttons;
