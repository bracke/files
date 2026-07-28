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
            Anchor : constant Natural := Files.Model.Selected_Index (Model);
         begin
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
