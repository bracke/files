separate (Files_Suite.Rendering)
   procedure Test_Compact_Overlay_Commands_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Widths  : constant array (Positive range <>) of Natural :=
        [0, 1, 5, 20, 80, 279, 360, 640];
      Heights : constant array (Positive range <>) of Natural :=
        [0, 1, 2, 20, 72, 100, 200];
   begin
      for Scenario in 1 .. 10 loop
         declare
            Snap : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         begin
            Snap.Command_Enabled := [others => True];
            case Scenario is
               when 1 =>
                  Snap.Paste_Conflict_Open := True;
                  Snap.Paste_Conflict_Name := To_Unbounded_String ("conflict.txt");
               when 2 =>
                  Snap.Paste_Progress_Open := True;
                  Snap.Paste_Progress_Done := 1;
                  Snap.Paste_Progress_Total := 2;
                  Snap.Paste_Progress_Name := To_Unbounded_String ("copy.txt");
               when 3 =>
                  Snap.Quick_Look_Open := True;
                  Snap.Quick_Look_Kind := Files.Quick_Look.Info_Content;
                  Snap.Quick_Look_Name := To_Unbounded_String ("preview.txt");
               when 4 =>
                  Snap.Label_Picker_Open := True;
               when 5 =>
                  Snap.Sort_Menu_Open := True;
               when 6 =>
                  Snap.Command_Palette_Open := True;
               when 7 =>
                  Snap.Settings_Pane_Open := True;
               when 8 =>
                  Snap.Context_Menu_Open := True;
                  Snap.Context_Menu_Target := Files.Types.Context_Menu_Item;
                  Snap.Context_Menu_X := 10;
                  Snap.Context_Menu_Y := 10;
               when 9 =>
                  Snap.Root_Selector_Open := True;
                  Snap.Root_Selected_Index := 1;
                  Snap.Root_Paths.Append (To_Unbounded_String ("/"));
                  Snap.Root_Labels.Append (To_Unbounded_String ("Filesystem"));
               when others =>
                  Snap.Tree_Panel_Open := True;
            end case;

            for Width of Widths loop
               for Height of Heights loop
                  declare
                     Frame : constant Frame_Commands :=
                       Build_Frame_Commands (Snap, Width, Height, 20);
                  begin
                     for Command of Frame.Overlay_Rectangles loop
                        Files_Suite.Support.Assert_Fits
                          (Command.X, Command.Y, Command.Width, Command.Height, Width, Height,
                           "overlay rectangles stay inside the compact framebuffer");
                     end loop;
                     for Command of Frame.Overlay_Text loop
                        Files_Suite.Support.Assert_Fits
                          (Command.X, Command.Y, Command.Width, Command.Height, Width, Height,
                           "overlay text stays inside the compact framebuffer");
                     end loop;
                     for Node of Frame.Accessibility loop
                        Files_Suite.Support.Assert_Fits
                          (Node.X, Node.Y, Node.Width, Node.Height, Width, Height,
                           "overlay accessibility stays inside the compact framebuffer");
                     end loop;
                     for Hit of Frame.Conflict_Hits loop
                        Assert
                          (Hit.Kind /= Conflict_Hit_None,
                           "dialog hit regions stay inside the compact framebuffer (hit kind)");
                        Files_Suite.Support.Assert_Fits
                          (Hit.X, Hit.Y, Hit.Width, Hit.Height, Width, Height,
                           "dialog hit regions stay inside the compact framebuffer");
                     end loop;
                     for Icon of Frame.Icons loop
                        if Icon.Overlay then
                           declare
                              Draw_W : constant Natural :=
                                (if Icon.Draw_Width > 0 then Icon.Draw_Width else Icon.Size);
                              Draw_H : constant Natural :=
                                (if Icon.Draw_Height > 0 then Icon.Draw_Height else Icon.Size);
                           begin
                              Files_Suite.Support.Assert_Fits
                                (Icon.X, Icon.Y, Draw_W, Draw_H, Width, Height,
                                 "overlay icons stay inside the compact framebuffer");
                           end;
                        end if;
                     end loop;
                  end;
               end loop;
            end loop;
         end;
      end loop;
   end Test_Compact_Overlay_Commands_Bounded;
