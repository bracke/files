separate (Files.Controller.Handle_Key)
--  While the Quick Look overlay is open it owns the keyboard: Escape or
--  Space close it; the grid-navigation keys (arrows, Home/End, Page Up/Down)
--  move the selection underneath -- just as they would in the file grid --
--  and re-preview the newly selected item, so the user can flip through files
--  without leaving Quick Look. Every other key is swallowed so nothing behind
--  the modal-lite preview reacts.
procedure Quick_Look_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Files.Model.Quick_Look_Is_Open (Model) then
      if (Key = Guikit.Input.Key_Escape or else Key = Guikit.Input.Key_Space)
        and then Modifiers = Guikit.Input.No_Modifiers
      then
         Files.Model.Close_Quick_Look (Model);
         Result := Successful_Command_Result (Files.Commands.Toggle_Quick_Look_Command);
         return;
      elsif Modifiers = Guikit.Input.No_Modifiers
        and then (Key = Guikit.Input.Key_Up or else Key = Guikit.Input.Key_Down
                  or else Key = Guikit.Input.Key_Left or else Key = Guikit.Input.Key_Right
                  or else Key = Guikit.Input.Key_Home or else Key = Guikit.Input.Key_End
                  or else Key = Guikit.Input.Key_Page_Up or else Key = Guikit.Input.Key_Page_Down)
      then
         declare
            Old_Index : constant Natural := Files.Model.Selected_Index (Model);
         begin
            case Key is
               when Guikit.Input.Key_Up =>
                  Files.Model.Move_Selection (Model, Guikit.Input.Move_Up);
               when Guikit.Input.Key_Down =>
                  Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
               when Guikit.Input.Key_Left =>
                  Files.Model.Move_Selection (Model, Guikit.Input.Move_Left);
               when Guikit.Input.Key_Right =>
                  Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
               when Guikit.Input.Key_Home =>
                  Files.Model.Select_First_Visible (Model);
               when Guikit.Input.Key_End =>
                  Files.Model.Select_Last_Visible (Model);
               when Guikit.Input.Key_Page_Up =>
                  Files.Model.Move_Selection_By_Page (Model, Files.Model.Selection_Page_Rows (Model), False);
               when Guikit.Input.Key_Page_Down =>
                  Files.Model.Move_Selection_By_Page (Model, Files.Model.Selection_Page_Rows (Model), True);
               when others =>
                  null;
            end case;
            if Files.Model.Selected_Index (Model) = Old_Index then
               Result := Make_Result (Controller_Ignored);
               return;
            end if;
            Files.Model.Open_Quick_Look
              (Model, Files.Operations.Prepare_Quick_Look (Files.Model.Selected_Item (Model)));
            Result := Make_Result (Controller_Selection_Moved);
            return;
         end;
      end if;
      Result := Make_Result (Controller_Ignored);
      return;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Quick_Look_Key;
