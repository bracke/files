separate (Files_Suite.Rendering)
   --  Bug 14: the text-input caret height must scale with the font/line height,
   --  the way the glyph height does, rather than being a fixed size.
   procedure Test_Caret_Scales_With_Line_Height (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Caret_H (L : Positive) return Natural is
         Snapshot : View_Snapshot := Sample_Snapshot (3, Files.Types.Details);
         X, Y, W, H : Natural;
         Found      : Boolean;
      begin
         Snapshot.Focus := Files.Types.Focus_Path_Input;
         Snapshot.Path_Input_Text := To_Unbounded_String ("/home/user/example");
         Snapshot.Text_Cursor_Position := 4;
         Find_Caret (Build_Frame_Commands (Snapshot, 1000, 800, L), X, Y, W, H, Found);
         return (if Found then H else 0);
      end Caret_H;

      Small : constant Natural := Caret_H (20);
      Large : constant Natural := Caret_H (40);
   begin
      Assert (Small > 0 and then Large > 0, "a focused path input draws a caret at each font size");
      Assert (Large > Small, "the caret grows taller with a larger font/line height");
      --  A fixed-size caret would keep Large = Small; require the growth to
      --  track the line-height increase rather than a token amount.
      Assert
        (Large - Small >= (40 - 20) / 2,
         "the caret height tracks the line height instead of a fixed size");
      --  The caret height must be PROPORTIONAL to the line height (a constant
      --  fraction), not line-height-minus-a-fixed-inset which under-scales the
      --  caret at small fonts. Cross-multiplying, Small/20 must equal Large/40
      --  within integer rounding (this fails for a Line_Height-minus-constant
      --  caret, which is stubbier at small fonts).
      Assert
        (abs (Integer (Small) * 40 - Integer (Large) * 20) <= 40,
         "the caret height stays a constant fraction of the line height across font sizes");
   end Test_Caret_Scales_With_Line_Height;
