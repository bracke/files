with Files.Commands.Status;
separate (Files.Controller.Handle_Key)
procedure Context_Menu_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Files.Model.Context_Menu_Is_Open (Model) then
      if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Close_Context_Menu (Model);
         Result := Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         return;
      elsif (Key = Guikit.Input.Key_Up or else Key = Guikit.Input.Key_Down)
        and then Modifiers = Guikit.Input.No_Modifiers
      then
         declare
            use type Files.Commands.Context_Menu_Row_Kind;
            Rows : constant Files.Commands.Context_Menu_Rows :=
              Files.Commands.Context_Menu_Rows_For (Files.Model.Context_Menu_Target_Of (Model));
            Direction : constant Integer := (if Key = Guikit.Input.Key_Up then -1 else 1);
            Current   : constant Natural := Files.Model.Context_Menu_Highlight (Model);
            Index     : Integer :=
              (if Current /= 0 then Current
               elsif Direction > 0 then 0
               else Rows.Count + 1);
            Landed    : Natural := 0;
         begin
            --  Step to the next enabled command row, skipping separators and
            --  disabled entries; stop (leaving the highlight put) at the ends.
            loop
               Index := Index + Direction;
               exit when Index < 1 or else Index > Rows.Count;
               if Rows.Rows (Index).Kind = Files.Commands.Menu_Command
                 and then Files.Commands.Status.Is_Enabled (Rows.Rows (Index).Command, Model)
               then
                  Landed := Index;
                  exit;
               end if;
            end loop;
            if Landed /= 0 then
               Files.Model.Set_Context_Menu_Highlight (Model, Landed);
            end if;
            Result := Make_Result (Controller_Selection_Moved);
            return;
         end;
      else
         --  Enter is applied on the Interaction seam (running a menu command
         --  needs the settings path); every other key is consumed so the grid
         --  behind the menu stays put.
         Result := Make_Result (Controller_Ignored);
         return;
      end if;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Context_Menu_Key;
