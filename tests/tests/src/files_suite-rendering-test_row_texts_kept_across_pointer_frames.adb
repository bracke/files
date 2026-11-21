with Ada.Real_Time;
with Ada.Text_IO;
separate (Files_Suite.Rendering)
   --  A frame redrawn for a pointer move over the same snapshot build reads
   --  the Details rows' texts back instead of formatting them again; a new
   --  build formats them afresh, so a changed column set is drawn.
   procedure Test_Row_Texts_Kept_Across_Pointer_Frames
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use type Ada.Real_Time.Time;
      Width  : constant Natural  := 1000;
      Height : constant Natural := 800;
      LH     : constant Positive := 20;
      Snap   : View_Snapshot := Sample_Snapshot (30, Files.Types.Details);
      Texts  : Row_Text_Cache;

      function Frame (Build : Natural; Hover_Y : Natural) return Frame_Commands is
        (Build_Frame_Commands
           (Snap, Build, Texts, Width, Height, LH,
            (Hover_X => 200, Hover_Y => Hover_Y, Has_Hover => True, others => <>)));

      --  The first row's description in F.
      function Description (F : Frame_Commands) return String is
      begin
         for Node of F.Accessibility loop
            if Node.Name = Snap.Items (1).Name then
               return To_String (Node.Description);
            end if;
         end loop;
         return "";
      end Description;

      function Uncached (Hover_Y : Natural) return Frame_Commands is
        (Build_Frame_Commands
           (Snap, Width, Height, LH, (Hover_X => 200, Hover_Y => Hover_Y, Has_Hover => True, others => <>)));
   begin
      for Item of Snap.Items loop
         Item.Size_Available := True;
         Item.Size := 2048;
         Item.Permissions := To_Unbounded_String ("rw-r--r--");
      end loop;

      declare
         First  : constant Frame_Commands := Frame (Build => 7, Hover_Y => 100);
         Formatted : constant Natural := Formatted_Rows (Texts);
         Second : constant Frame_Commands := Frame (Build => 7, Hover_Y => 140);
         Plain  : constant Frame_Commands := Uncached (140);
      begin
         Assert (Formatted > 0, "the drawn rows' texts are kept");
         Assert (Formatted_Rows (Texts) = Formatted, "a pointer frame over the same build formats no row again");
         Assert
           (Guikit.Draw.Text_Command_Vectors."=" (Second.Text, Plain.Text),
            "a frame from kept texts draws what a fresh frame draws");
         Assert
           (Guikit.Draw.Accessibility_Node_Vectors."=" (Second.Accessibility, Plain.Accessibility),
            "and describes the rows the same");
         Assert (Description (First) = Description (Second), "the row reads the same across pointer frames");
      end;

      --  A new build (here: permissions shown) is formatted afresh.
      Snap.Detail_Columns_Visible (Files.Types.Permissions_Column) := True;
      declare
         Rebuilt : constant Frame_Commands := Frame (Build => 8, Hover_Y => 140);
      begin
         Assert (Contains (Description (Rebuilt), "rw-r--r--"), "a new build's rows are formatted again");
      end;

      --  What the kept texts save on a pointer move, for the record.
      declare
         Rounds : constant := 200;
         Start  : Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Kept, Fresh : Duration;
      begin
         for Round in 1 .. Rounds loop
            declare
               F : constant Frame_Commands := Frame (Build => 8, Hover_Y => 100 + Round mod 300);
               pragma Unreferenced (F);
            begin
               null;
            end;
         end loop;
         Kept := Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Start);
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            declare
               F : constant Frame_Commands := Uncached (100 + Round mod 300);
               pragma Unreferenced (F);
            begin
               null;
            end;
         end loop;
         Fresh := Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Start);
         Ada.Text_IO.Put_Line
           ("row-texts: pointer frame" & Duration'Image (Kept / Rounds * 1000) & " ms kept vs"
            & Duration'Image (Fresh / Rounds * 1000) & " ms formatted");
      end;
   end Test_Row_Texts_Kept_Across_Pointer_Frames;
