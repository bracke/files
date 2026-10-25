separate (Files_Suite.Rendering)
   --  The sort button's content (the field label plus its direction arrow) sits
   --  horizontally centred in the button, not left-aligned against the padding.
   procedure Test_Sort_Label_Centered (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      Bar      : constant Guikit.Layout.Bottom_Bar_Layout :=
        Files.UI.Calculate_Bottom_Bar_Layout (1000, Files.Model.Sort_Name, 20);
      Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
      Cell_W   : constant Natural := Natural'Max (1, 20 * 12 / 20);
      Field    : constant String := Files.Localization.Text ("command.sort.name");
      Arrow    : constant String := Files.Localization.Text ("sort.direction.ascending");
      Arrow_W  : constant Natural := Files.UTF8.Display_Units (Arrow) * Cell_W;
      Field_X  : Integer := -1;
      Arrow_X  : Integer := -1;
   begin
      for C of Frame.Text loop
         if C.Y >= Bottom_Y then
            if To_String (C.Text) = Field then
               Field_X := C.X;
            elsif To_String (C.Text) = Arrow then
               Arrow_X := C.X;
            end if;
         end if;
      end loop;
      Assert (Field_X >= 0 and then Arrow_X >= 0, "the sort field label and its arrow are drawn");
      declare
         Left_Gap  : constant Integer := Field_X - Integer (Bar.Sort_Button_X);
         Right_Gap : constant Integer :=
           Integer (Bar.Sort_Button_X + Bar.Sort_Button_Width) - (Arrow_X + Integer (Arrow_W));
      begin
         Assert (abs (Left_Gap - Right_Gap) <= 1,
                 "the sort field label and arrow are centred (equal gaps each side)");
      end;
   end Test_Sort_Label_Centered;
