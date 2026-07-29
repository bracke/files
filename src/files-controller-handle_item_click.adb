separate (Files.Controller)
   function Handle_Item_Click
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Visible_Index : Natural;
      Activate      : Boolean := False;
      Modifiers     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result is
   begin
      if Files.Model.Command_Palette_Is_Open (Model)
        or else Files.Model.Root_Selector_Is_Open (Model)
        or else Files.Model.Settings_Pane_Is_Open (Model)
      then
         return Make_Result (Controller_Ignored);
      elsif Visible_Index = 0 or else Visible_Index > Files.Model.Visible_Count (Model) then
         return Make_Result (Controller_Ignored);
      end if;

      Files.Model.Cancel_Focus_Or_Edit (Model);
      if Visible_Index > Files.Model.Visible_Count (Model) then
         --  The clicked row was the trailing temporary (create-file) row, which
         --  Cancel_Focus_Or_Edit just removed; report a successful state-only
         --  cancel rather than an unrelated (close-palette) command id.
         return Successful_Command_Result (Files.Commands.No_Command);
      end if;

      if Modifiers (Guikit.Input.Shift_Key) and then not Activate then
         declare
            Old_Index : constant Natural := Files.Model.Selected_Index (Model);
            Old_Count : constant Natural := Files.Model.Selected_Count (Model);
            Anchor    : Natural := Old_Index;
         begin
            --  Keep the anchor at the fixed opposite end of the current
            --  selection, so successive shift-clicks grow the range from where
            --  it began rather than from the moving cursor (which
            --  Select_Visible_Range left on the last click's target). Without
            --  this a second shift-click shrinks the range. Mirrors the keyboard
            --  shift+arrow path in Handle_Key.
            if Old_Count > 1 then
               declare
                  First_Selected : Natural := 0;
                  Last_Selected  : Natural := 0;
               begin
                  for Index in 1 .. Files.Model.Visible_Count (Model) loop
                     if Files.Model.Is_Selected (Model, Positive (Index)) then
                        if First_Selected = 0 then
                           First_Selected := Index;
                        end if;
                        Last_Selected := Index;
                     end if;
                  end loop;

                  if Old_Index = Last_Selected then
                     Anchor := First_Selected;
                  elsif Old_Index = First_Selected then
                     Anchor := Last_Selected;
                  end if;
               end;
            end if;

            Files.Model.Select_Visible_Range
              (Model,
               Positive ((if Anchor = 0 then Visible_Index else Anchor)),
               Positive (Visible_Index));
         end;
      elsif Modifiers (Guikit.Input.Control_Key) and then not Activate then
         Files.Model.Toggle_Visible_Selection (Model, Positive (Visible_Index));
      else
         Files.Model.Select_Visible (Model, Positive (Visible_Index));
      end if;

      if Activate then
         return Execute_Command (Files.Commands.Open_Selected_Items_Command, Model, Settings, Modifiers);
      end if;

      return Make_Result (Controller_Selection_Moved);
   end Handle_Item_Click;
