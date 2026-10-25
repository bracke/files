separate (Files_Suite.Rendering)
   procedure Test_Large_Icon_Badges_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Widths : constant array (Positive range <>) of Natural :=
        [20, 40, 80, 139, 140, 141, 280, 421, 640];
      Heights : constant array (Positive range <>) of Natural := [173, 300];
      Snap   : View_Snapshot := Sample_Snapshot (12, Files.Types.Large_Icons);
      Found  : Boolean := False;
   begin
      for Index in 1 .. Natural (Snap.Items.Length) loop
         declare
            Item : Item_Snapshot := Snap.Items.Element (Positive (Index));
         begin
            Item.Name := To_Unbounded_String ("item" & Integer'Image (Index) & ".txt");
            Snap.Items.Replace_Element (Positive (Index), Item);
         end;
      end loop;

      for Width of Widths loop
         for Height of Heights loop
            declare
               Layout : constant Guikit.Draw.Layout_Metrics :=
                 Calculate_Layout (Snap, Width, Height, 20);
               Frame  : constant Frame_Commands :=
                 Build_Frame_Commands (Snap, Width, Height, 20);
            begin
               for Rect of Frame.Overlay_Rectangles loop
                  Files_Suite.Support.Assert_Inside
                    (Rect.X, Rect.Y, Rect.Width, Rect.Height,
                     Layout.Main_X, Layout.Main_Y, Layout.Main_Width, Layout.Main_Height,
                     "extension-badge backgrounds stay inside the main viewport");
               end loop;
               for Icon of Frame.Icons loop
                  if Ada.Strings.Fixed.Index (To_String (Icon.Icon_Id), "extlabel:") = 1 then
                     Found := True;
                     Files_Suite.Support.Assert_Inside
                       (Icon.X, Icon.Y, Icon.Draw_Width, Icon.Draw_Height,
                        Layout.Main_X, Layout.Main_Y, Layout.Main_Width, Layout.Main_Height,
                        "extension-label bitmaps stay inside the main viewport");
                  end if;
               end loop;
            end;
         end loop;
      end loop;
      Assert (Found, "the large-icon cases render at least one extension badge");
   end Test_Large_Icon_Badges_Bounded;
