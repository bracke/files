separate (Files_Suite.Rendering)
   procedure Test_Info_Pane_Content_Clipped (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width         : constant Natural := 640;
      LH            : constant Positive := 20;
      Found_Clipped : Boolean := False;
      Sample_Info   : Info_Snapshot;
   begin
      Sample_Info.Name := To_Unbounded_String ("compact.txt");
      Sample_Info.Filetype := To_Unbounded_String ("text/plain");
      Sample_Info.Size_Available := True;
      Sample_Info.Size := 1_024;
      Sample_Info.Mode_Available := True;
      Sample_Info.Mode_Bits := 8#640#;
      Sample_Info.Ownership_Available := True;
      Sample_Info.Owner_Name := To_Unbounded_String ("owner");
      Sample_Info.Group_Name := To_Unbounded_String ("group");
      Sample_Info.Filetype_Extra := To_Unbounded_String ("compact metadata");

      for Selection_Count in 0 .. 2 loop
         declare
            Snap : View_Snapshot := Sample_Snapshot (3, Files.Types.Details);
         begin
            Snap.Info_Pane_Open := True;
            Snap.Permissions_Editable := True;
            Snap.Ownership_Editable := True;
            Snap.Info_Pane_Scroll_Lines :=
              (if Selection_Count = 1 then 19 elsif Selection_Count = 2 then 2 else 0);
            for Index in 1 .. Selection_Count loop
               Sample_Info.Name := To_Unbounded_String ("compact" & Integer'Image (Index) & ".txt");
               Snap.Selected_Info.Append (Sample_Info);
            end loop;

            for Height in 90 .. 150 loop
               declare
                  Layout : constant Guikit.Draw.Layout_Metrics :=
                    Calculate_Layout (Snap, Width, Height, LH);
                  Info   : constant Info_Pane_Layout :=
                    Calculate_Info_Pane_Layout (Snap, Layout, LH);
                  Frame  : constant Frame_Commands :=
                    Build_Frame_Commands (Snap, Width, Height, LH);
                  Right  : constant Natural := Info.X + Info.Width;
                  Bottom : constant Natural := Info.Y + Info.Height;
               begin
                  for Command of Frame.Text loop
                     if Command.X >= Info.X and then Command.X < Right
                       and then Command.Y >= Info.Y and then Command.Y < Bottom
                     then
                        Assert
                          (Command.Height <= Bottom - Command.Y,
                           "information-pane text stays above the bottom bar");
                        Found_Clipped := Found_Clipped or else Command.Height < LH;
                     end if;
                  end loop;

                  for Tip of Frame.Tooltips loop
                     if Tip.X >= Info.X and then Tip.X < Right
                       and then Tip.Y >= Info.Y and then Tip.Y < Bottom
                     then
                        Assert
                          (Tip.Height <= Bottom - Tip.Y,
                           "information-pane tooltip regions stay inside the pane");
                     end if;
                  end loop;

                  for Node of Frame.Accessibility loop
                     if Node.X >= Info.X and then Node.X < Right
                       and then (Node.Role = Role_Pane or else Node.Role = Role_List_Item)
                     then
                        Assert (Node.Y >= Info.Y, "information-pane accessibility nodes stay inside the pane (top)");
                        Assert
                          (Node.Y <= Bottom,
                           "information-pane accessibility nodes stay inside the pane (start above the bottom)");
                        Assert
                          (Node.Height <= Bottom - Node.Y,
                           "information-pane accessibility nodes stay inside the pane (height)");
                     end if;
                  end loop;

                  for Hit of Frame.Permission_Hits loop
                     Assert (Hit.Y >= Info.Y, "permission hit regions stay inside the information pane (top)");
                     Assert
                       (Hit.Y <= Bottom,
                        "permission hit regions stay inside the information pane (start above the bottom)");
                     Assert
                       (Hit.Height <= Bottom - Hit.Y,
                        "permission hit regions stay inside the information pane (height)");
                  end loop;
                  for Hit of Frame.Ownership_Hits loop
                     Assert (Hit.Y >= Info.Y, "ownership hit regions stay inside the information pane (top)");
                     Assert
                       (Hit.Y <= Bottom,
                        "ownership hit regions stay inside the information pane (start above the bottom)");
                     Assert
                       (Hit.Height <= Bottom - Hit.Y,
                        "ownership hit regions stay inside the information pane (height)");
                  end loop;
               end;
            end loop;
         end;
      end loop;

      Assert (Found_Clipped, "the compact-height cases exercise a partially visible metadata row");
   end Test_Info_Pane_Content_Clipped;
