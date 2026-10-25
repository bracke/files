separate (Files_Suite.Rendering)
   --  Free space is drawn as its own field (separate from the hidden/visible
   --  counts) with a vertical divider between them in the info region.
   procedure Test_Free_Space_Separate_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap     : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Free_Sfx : constant String := Files.Localization.Text ("status.free_space.suffix");
      Vis_Lbl  : constant String := Files.Localization.Text ("status.visible");
   begin
      Snap.Free_Space_Known := True;
      Snap.Free_Space_Bytes := 12_000_000_000;
      declare
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Frame    : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bar      : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Snap.Sort_Field, 20);
         Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
         Free_Cmd : Boolean := False;
         Counts_Has_Free : Boolean := False;
         Divider  : Boolean := False;
      begin
         for C of Frame.Text loop
            if C.Y >= Bottom_Y then
               if Ada.Strings.Fixed.Index (To_String (C.Text), Free_Sfx) > 0 then
                  Free_Cmd := True;
                  --  The free-space command must not also carry the counts text.
                  if Ada.Strings.Fixed.Index (To_String (C.Text), Vis_Lbl) > 0 then
                     Counts_Has_Free := True;
                  end if;
               end if;
            end if;
         end loop;
         --  A 1px vertical divider inside the info region (excludes the view
         --  switcher's own cell dividers, which sit further left), spanning close
         --  to the full bar height.
         for R of Frame.Rectangles loop
            if R.Width = 1 and then R.Color = Border_Color
              and then R.Y >= Bottom_Y and then R.X >= Bar.Info_X
              and then R.X < Bar.Info_X + Bar.Info_Width
            then
               Divider := True;
               Assert (R.Height >= Layout.Bottom_Bar_Height - 2,
                       "the divider spans nearly the full bottom-bar height");
            end if;
         end loop;
         Assert (Free_Cmd, "free space is drawn in the bottom bar");
         Assert (not Counts_Has_Free, "free space is a separate field, not folded into the counts");
         Assert (Divider, "a vertical divider separates the free-space field from the counts");
      end;
   end Test_Free_Space_Separate_Field;
