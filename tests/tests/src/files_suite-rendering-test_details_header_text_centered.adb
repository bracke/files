separate (Files_Suite.Rendering)
   --  The details-view header labels are optically centred in the header field
   --  using the same vertical offset as the (accepted) bottom-bar text, rather
   --  than sitting low at the full geometric inset.
   procedure Test_Details_Header_Text_Centered (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap     : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Mod_Lbl  : constant String := Files.Localization.Text ("details.modified");
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
      Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
      Bottom_Top : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;

      Header_Field_Top : Integer := -1;   --  top of the header background band
      Header_Text_Y    : Integer := -1;
      Bottom_Text_Y    : Integer := -1;
   begin
      --  Header background: the topmost content-width band (not a hairline).
      for R of Frame.Rectangles loop
         if R.Width in 900 .. 999 and then R.Height > 10 and then R.Y < Bottom_Top
           and then (Header_Field_Top < 0 or else R.Y < Header_Field_Top)
         then
            Header_Field_Top := R.Y;
         end if;
      end loop;
      for C of Frame.Text loop
         if To_String (C.Text) = Mod_Lbl then
            Header_Text_Y := C.Y;
         elsif C.Y >= Bottom_Top and then (Bottom_Text_Y < 0 or else C.Y < Bottom_Text_Y) then
            Bottom_Text_Y := C.Y;
         end if;
      end loop;
      Assert (Header_Field_Top >= 0,
              "the header field, header label and a bottom-bar label are all present (header field)");
      Assert (Header_Text_Y >= 0,
              "the header field, header label and a bottom-bar label are all present (header label)");
      Assert (Bottom_Text_Y >= 0,
              "the header field, header label and a bottom-bar label are all present (bottom-bar label)");
      --  Same offset within their fields: both optically centred alike.
      Files_Suite.Support.Assert_Equal
        (Header_Text_Y - Header_Field_Top,
         Bottom_Text_Y - Bottom_Top,
         "the header label sits at the same vertical offset as the bottom-bar text");
   end Test_Details_Header_Text_Centered;
