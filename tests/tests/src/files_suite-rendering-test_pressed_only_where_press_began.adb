with Files.Preference_Types;
with Files.Rendering.Layouts;
with Guikit.Layout;
separate (Files_Suite.Rendering)
   --  A held button presses the control under the pointer only when the
   --  press began on it: a scrollbar, column or marquee drag that crosses the
   --  path field leaves it unpressed.
   procedure Test_Pressed_Only_Where_Press_Began (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width : constant := 900;
      Snap  : constant View_Snapshot := Sample_Snapshot (6, Files.Preference_Types.Details);
      Box   : constant Files.Rendering.Layouts.Field_Text_Region :=
        Files.Rendering.Layouts.Path_Field_Text_Region (Guikit.Layout.Calculate_Toolbar_Layout (Width, 20), Width, 20);
      X     : constant Natural := Box.Field_X + Box.Field_Width / 2;
      Y     : constant Natural := Guikit.Layout.Toolbar_Input_Y (20) + Guikit.Layout.Toolbar_Input_Height (20) / 2;

      function Pressed_Drawn (Press_X, Press_Y : Natural) return Boolean is
         Frame : constant Frame_Commands :=
           Build_Frame_Commands
             (Snap, Width, 480, 20,
              Pointer =>
                (Hover_X => X, Hover_Y => Y, Has_Hover => True,
                 Pressed => True, Press_X => Press_X, Press_Y => Press_Y, others => <>));
      begin
         for Rect of Frame.Rectangles loop
            if Rect.Color = Guikit.Draw.Pressed_Color then
               return True;
            end if;
         end loop;
         return False;
      end Pressed_Drawn;
   begin
      Assert (Box.Field_Width > 0, "the path field is drawn at this width");
      Assert (Pressed_Drawn (X, Y), "a press that began on the field presses it");
      Assert (not Pressed_Drawn (X, 470), "a drag from the view below that crosses it does not");
   end Test_Pressed_Only_Where_Press_Began;
