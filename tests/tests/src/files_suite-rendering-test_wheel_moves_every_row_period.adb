with Files.Preference_Types;
with Files.Input_Actions;
with Files.Rendering.Layouts;
separate (Files_Suite.Rendering)
   --  A wheel notch asks for three lines, but the main view draws its offset
   --  snapped down to whole row periods. In Large Icons a row period (a cell
   --  plus its gap) is far from a whole number of lines, so a step made in
   --  lines alone landed inside the row already shown about every other
   --  notch and moved nothing. Every notch must move the drawn rows, down to
   --  the end and back up to the top, in every view mode.
   procedure Test_Wheel_Moves_Every_Row_Period (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Modes : constant array (1 .. 3) of Files.Preference_Types.View_Mode :=
        [Files.Preference_Types.Small_Icons, Files.Preference_Types.Large_Icons, Files.Preference_Types.Details];
      Width  : constant Natural := 900;
      Height : constant Natural := 600;
      LH     : constant Positive := 20;
   begin
      for Mode of Modes loop
         declare
            Snapshot : View_Snapshot := Sample_Snapshot (400, Mode);
            Layout   : constant Guikit.Draw.Layout_Metrics :=
              Calculate_Layout (Snapshot, Width => Width, Height => Height, Line_Height => LH);
            X        : constant Natural := Layout.Main_X + Layout.Main_Width / 2;
            Y        : constant Natural := Layout.Main_Y + Layout.Main_Height / 2;

            function Drawn return Natural is
              (Files.Rendering.Layouts.Calculate_Main_View_Layout (Snapshot, Layout, LH).Scroll_Pixels);

            --  One notch (Y_Offset -1 down, +1 up) applied to the snapshot;
            --  False when the wheel produced nothing.
            function Notch (Y_Offset : Integer) return Boolean is
               Action : constant Files.Input_Actions.Input_Action :=
                 Files.Events.Translate_Scroll_At
                   (Snapshot, X, Y, Width, Height, Y_Offset => Y_Offset, Line_Height => LH);
            begin
               if Action.Kind /= Files.Input_Actions.Scroll_Input_Action then
                  return False;
               end if;
               Snapshot.Main_View_Scroll_Lines :=
                 Natural (Integer (Snapshot.Main_View_Scroll_Lines) + Action.Scroll_Lines);
               return True;
            end Notch;

            Name    : constant String := Files.Preference_Types.View_Mode'Image (Mode);
            Notches : Natural := 0;
         begin
            Assert
              (Files.Rendering.Layouts.Calculate_Main_View_Layout (Snapshot, Layout, LH).Scrollbar_Visible,
               Name & ": the fixture overflows the main view");
            --  Down to the end: every notch moves the drawn offset.
            loop
               declare
                  Before : constant Natural := Drawn;
               begin
                  exit when not Notch (-1);
                  Notches := Notches + 1;
                  Assert (Drawn > Before, Name & ": wheel-down notch" & Notches'Image & " moved the rows");
                  exit when Notches > 10_000;
               end;
            end loop;
            Assert (Notches > 2, Name & ": several notches reach the end of the list");
            --  Back up to the top: every notch moves again.
            Notches := 0;
            loop
               declare
                  Before : constant Natural := Drawn;
               begin
                  exit when not Notch (1);
                  Notches := Notches + 1;
                  Assert (Drawn < Before, Name & ": wheel-up notch" & Notches'Image & " moved the rows");
                  exit when Notches > 10_000;
               end;
            end loop;
            Files_Suite.Support.Assert_Equal (Drawn, 0, Name & ": wheeling up returns to the top");
         end;
      end loop;
   end Test_Wheel_Moves_Every_Row_Period;
