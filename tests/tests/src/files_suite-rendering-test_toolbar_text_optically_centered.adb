separate (Files_Suite.Rendering)
   --  The toolbar input text is optically centred in its field the same way as
   --  the (accepted) bottom-bar text, so it lines up vertically with the
   --  geometric-centred toolbar icons and favourite star.
   procedure Test_Toolbar_Text_Optically_Centered (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap        : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Frame       : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
      Layout      : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
      Toolbar_Top : constant Natural := Guikit.Layout.Toolbar_Input_Y (20);
      Field_H     : constant Natural := Guikit.Layout.Toolbar_Input_Height (20);
      Field_Ctr   : constant Natural := Toolbar_Top + Field_H / 2;
      Bottom_Top  : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;

      Toolbar_Text_Y : Integer := -1;
      Bottom_Text_Y  : Integer := -1;
      Icon_Center    : Integer := -1;
   begin
      for C of Frame.Text loop
         if C.Y >= Toolbar_Top and then C.Y < Layout.Toolbar_Height
           and then (Toolbar_Text_Y < 0 or else C.Y < Toolbar_Text_Y)
         then
            Toolbar_Text_Y := C.Y;
         elsif C.Y >= Bottom_Top and then (Bottom_Text_Y < 0 or else C.Y < Bottom_Text_Y) then
            Bottom_Text_Y := C.Y;
         end if;
      end loop;
      for I of Frame.Icons loop
         if I.Y < Layout.Toolbar_Height and then Icon_Center < 0 then
            Icon_Center := I.Y + I.Size / 2;
         end if;
      end loop;
      Assert (Toolbar_Text_Y >= 0,
              "a toolbar text, a bottom-bar text and a toolbar icon are all present (toolbar text)");
      Assert (Bottom_Text_Y >= 0,
              "a toolbar text, a bottom-bar text and a toolbar icon are all present (bottom-bar text)");
      Assert (Icon_Center >= 0,
              "a toolbar text, a bottom-bar text and a toolbar icon are all present (toolbar icon)");
      --  Text: same optical offset within its field as the bottom-bar text.
      Files_Suite.Support.Assert_Equal
        (Toolbar_Text_Y - Toolbar_Top,
         Bottom_Text_Y - Bottom_Top,
         "toolbar text uses the same optical centring as the bottom-bar text");
      --  Icons: geometrically centred in the toolbar field (within rounding).
      Assert (abs (Icon_Center - Field_Ctr) <= 1,
              "the toolbar icon is centred in the toolbar field");
   end Test_Toolbar_Text_Optically_Centered;
