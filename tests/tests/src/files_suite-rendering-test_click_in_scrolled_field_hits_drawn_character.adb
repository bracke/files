with Files.Input_Actions;
separate (Files_Suite.Rendering)
   --  A focused filter field scrolled so that column 2 falls inside a wide
   --  character: the character scrolls off whole and the drawing starts after
   --  it, so a click must count columns from there, not from column 2.
   procedure Test_Click_In_Scrolled_Field_Hits_Drawn_Character
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      LH      : constant Positive := 20;
      Width   : constant Natural := 900;
      Height  : constant Natural := 600;
      Char_W  : constant Positive := Guikit.Layout.Caret_Advance_Width (LH);
      --  "a" (column 0), U+6F22 (columns 1-2), then letters from column 3.
      Wide    : constant String :=
        Character'Val (16#E6#) & Character'Val (16#BC#) & Character'Val (16#A2#);
      Raw     : constant String := "a" & Wide & "bcdefghijklmnopqrstuvwxyzbcdefghijklmnopqrstuvwxyz";
      Toolbar : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Width, LH);
      Filter  : constant Field_Text_Region := Filter_Field_Text_Region (Toolbar, LH);
      Caret   : Natural := 0;
   begin
      --  A caret whose scroll lands inside the wide character.
      for Offset in 0 .. Raw'Length loop
         if Input_Scroll_Columns (Raw, Offset, Filter.Width, LH) = 2 then
            Caret := Offset;
            exit;
         end if;
      end loop;
      Assert (Caret > 0, "some caret scrolls the field by exactly two columns");
      Files_Suite.Support.Assert_Equal
        (Field_View (Raw, Caret, Filter.Width, LH).Skip_Bytes, 1 + Wide'Length,
         "the wide character that straddles column 2 scrolls off with the a before it");

      declare
         Snapshot : View_Snapshot := Sample_Snapshot (3, Files.Types.Details);
      begin
         Snapshot.Filter_Text := To_Unbounded_String (Raw);
         Snapshot.Focus := Files.UI_Types.Focus_Filter_Input;
         Snapshot.Text_Cursor_Position := Caret;
         declare
            Frame  : constant Frame_Commands := Build_Frame_Commands (Snapshot, Width, Height, LH);
            --  Drawn from column 3: b, c, d, e, then f at four columns in. A
            --  click on that boundary puts the caret before f.
            Action : constant Files.Input_Actions.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, Filter.X + 4 * Char_W, Guikit.Layout.Toolbar_Input_Y (LH) + 2,
                 Width, Height, Line_Height => LH);
         begin
            Assert (Action.Kind = Files.Input_Actions.Text_Click_Input_Action, "the click focuses the filter text");
            Files_Suite.Support.Assert_Equal
              (Action.Cursor_Position, 1 + Wide'Length + 4,
               "the caret lands before f, the character drawn under the click");
         end;
      end;
   end Test_Click_In_Scrolled_Field_Hits_Drawn_Character;
