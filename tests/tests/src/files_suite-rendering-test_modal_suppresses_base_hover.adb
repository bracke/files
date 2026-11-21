with Files.Preference_Types;
separate (Files_Suite.Rendering)
   procedure Test_Modal_Suppresses_Base_Hover (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Base   : constant View_Snapshot := Sample_Snapshot (6, Files.Preference_Types.Small_Icons);
      Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Base, 1000, 800, 20);
      Items  : constant Item_Layout_Vectors.Vector := Calculate_Item_Layout (Base, Layout, 20);
      Cell   : Item_Layout;
      Found  : Boolean := False;
   begin
      for C of Items loop
         if C.Visible_Index = 2 then
            Cell  := C;
            Found := True;
         end if;
      end loop;
      Assert (Found, "a layout cell exists for the hovered item");

      declare
         Pointer : constant Pointer_State :=
           (Hover_X => Cell.X + Cell.Width / 2,
            Hover_Y => Cell.Y + Cell.Height / 2,
            Has_Hover => True,
            Pressed   => True,
            Press_X   => Cell.X + Cell.Width / 2,
            Press_Y   => Cell.Y + Cell.Height / 2,
            others    => <>);
         Looking : View_Snapshot := Base;
         Pasting : View_Snapshot := Base;
      begin
         Assert
           (Cell_Has_Hover_Highlight (Build_Frame_Commands (Base, 1000, 800, 20, Pointer => Pointer), Cell),
            "with no overlay open the item under the pointer is drawn hovered");

         --  Quick Look and the paste dialogs own the pointer: the view under
         --  them shows no hover, whatever lies under the pointer.
         Looking.Quick_Look.Open := True;
         Assert
           (Overlay_Open (Looking, Files.UI_Types.Quick_Look_Overlay)
            and then not Cell_Has_Hover_Highlight
              (Build_Frame_Commands (Looking, 1000, 800, 20, Pointer => Pointer), Cell),
            "with Quick Look open the item under the pointer is not drawn hovered");

         Pasting.Paste_Conflict_Open := True;
         Assert
           (Overlay_Open (Pasting, Files.UI_Types.Paste_Conflict_Overlay)
            and then not Cell_Has_Hover_Highlight
              (Build_Frame_Commands (Pasting, 1000, 800, 20, Pointer => Pointer), Cell),
            "with a paste dialog open the item under the pointer is not drawn hovered");
      end;
   end Test_Modal_Suppresses_Base_Hover;
