with Files.Commands.Context_Menus;
with Files.Commands.Status;
with Files.Model.Context_Menu;
separate (Files.Controller.Handle_Key)
--  The context menu on top owns the keyboard: Up and Down step over its
--  enabled command rows, Enter asks for the highlighted row to be run (as
--  a click on it is, by the interaction layer, which holds the settings
--  path), and every other key is consumed so the grid behind stays put.
procedure Context_Menu_Key (Handled : out Boolean; Result : out Controller_Result) is
   use type Files.Commands.Context_Menus.Context_Menu_Row_Kind;
   Rows      : constant Files.Commands.Context_Menus.Context_Menu_Rows :=
     Files.Commands.Context_Menus.Context_Menu_Rows_For (Files.Model.Context_Menu.Target_Of (Model));
   Current   : constant Natural := Files.Model.Context_Menu.Highlight (Model);
begin
   Handled := True;
   Result := Make_Result (Controller_Ignored);
   if Modifiers /= Guikit.Input.No_Modifiers then
      return;
   end if;
   case Key is
      when Guikit.Input.Key_Up | Guikit.Input.Key_Down =>
         declare
            Direction : constant Integer := (if Key = Guikit.Input.Key_Up then -1 else 1);
            Index     : Integer :=
              (if Current /= 0 then Current
               elsif Direction > 0 then 0
               else Rows.Count + 1);
         begin
            --  Step to the next enabled command row, skipping separators and
            --  disabled entries; stop (leaving the highlight put) at the ends.
            loop
               Index := Index + Direction;
               exit when Index < 1 or else Index > Rows.Count;
               if Rows.Rows (Index).Kind = Files.Commands.Context_Menus.Menu_Command
                 and then Files.Commands.Status.Is_Enabled (Rows.Rows (Index).Command, Model)
               then
                  Files.Model.Context_Menu.Set_Highlight (Model, Index);
                  exit;
               end if;
            end loop;
            Result :=
              Changed_Result (Current, Files.Model.Context_Menu.Highlight (Model), Controller_Selection_Moved);
         end;
      when Guikit.Input.Key_Return =>
         if Current in 1 .. Rows.Count
           and then Rows.Rows (Current).Kind = Files.Commands.Context_Menus.Menu_Command
         then
            Result :=
              (Make_Result (Controller_Activation_Requested, Rows.Rows (Current).Command) with delta
                 Activation => Run_Menu_Row);
         else
            --  Nothing highlighted (a mouse-opened menu not yet arrowed): a
            --  bare Enter just dismisses it.
            Files.Model.Context_Menu.Close (Model);
            Result := Successful_Command_Result (Files.Commands.Close_Overlay_Command);
         end if;
      when others =>
         null;
   end case;
end Context_Menu_Key;
