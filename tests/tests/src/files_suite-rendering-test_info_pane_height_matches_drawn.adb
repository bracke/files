separate (Files_Suite.Rendering)
   --  The height the info pane is laid out for follows the rows its text is
   --  drawn in: both wrap at the same width (the scrollbar's column left free
   --  whether it shows or not) by the same walk. Drawn wider, a value took
   --  fewer rows than were counted, and the pane scrolled past its end.
   procedure Test_Info_Pane_Height_Matches_Drawn (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural := 640;
      Height : constant Natural := 2_000;
      LH     : constant Positive := 20;
      Slack  : Integer := -1;
      Words  : constant String := "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu ";
   begin
      for Length in 20 .. Words'Length * 3 loop
         declare
            Snap : View_Snapshot := Sample_Snapshot (3, Files.Types.Details);
            Info : Info_Snapshot;
            Text : String (1 .. Length);
         begin
            for Index in Text'Range loop
               Text (Index) := Words ((Index - 1) mod Words'Length + 1);
            end loop;
            Info.Name := To_Unbounded_String ("long.txt");
            Info.Filetype := To_Unbounded_String ("text/plain");
            Info.Filetype_Extra := To_Unbounded_String (Text);
            Snap.Info_Pane_Open := True;
            Snap.Selected_Info.Append (Info);
            declare
               Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, Width, Height, LH);
               Pane   : constant Info_Pane_Layout := Calculate_Info_Pane_Layout (Snap, Layout, LH);
               Frame  : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
               Top    : Natural := Natural'Last;
               Bottom : Natural := 0;
            begin
               Assert (not Pane.Scrollbar_Visible, "the pane is tall enough to need no scrollbar");
               for Command of Frame.Text loop
                  if Command.X >= Pane.X and then Command.X < Pane.X + Pane.Width / 2
                    and then Command.Y >= Pane.Y and then Command.Y < Pane.Y + Pane.Height
                  then
                     Top := Natural'Min (Top, Command.Y);
                     Bottom := Natural'Max (Bottom, Command.Y + LH);
                  end if;
               end loop;
               Assert (Top < Bottom, "the pane draws its text");
               --  Laid out: the drawn rows, the padding above and below them,
               --  and the spacing after the last section -- the same for any
               --  value, so a row drawn but not counted (or counted but not
               --  drawn) shows as a change.
               if Slack < 0 then
                  Slack := Pane.Content_Height - (Bottom - Pane.Y) - (Top - Pane.Y);
               end if;
               Files_Suite.Support.Assert_Equal
                 (Pane.Content_Height - (Bottom - Pane.Y) - (Top - Pane.Y),
                  Slack,
                  "the laid-out height follows the drawn rows for a value of" & Length'Image & " bytes");
            end;
         end;
      end loop;
   end Test_Info_Pane_Height_Matches_Drawn;
