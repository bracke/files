separate (Files.Controller)
   function Handle_Targeted_Scroll
     (Model  : in out Files.Model.Window_Model;
      Target : Files.Events.Scroll_Target;
      Lines  : Integer)
      return Controller_Result is
   begin
      if Lines = 0 then
         return Make_Result (Controller_Ignored);
      end if;

      if Files.Model.Command_Palette_Is_Open (Model)
        and then Target /= Files.Events.Scroll_Auto
        and then Target /= Files.Events.Scroll_Command_Palette
      then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Root_Selector_Is_Open (Model)
        and then not Files.Model.Command_Palette_Is_Open (Model)
      then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Settings_Pane_Is_Open (Model)
        and then not Files.Model.Command_Palette_Is_Open (Model)
        and then Target /= Files.Events.Scroll_Auto
        and then Target /= Files.Events.Scroll_Settings_Pane
      then
         return Make_Result (Controller_Ignored);
      end if;

      case Target is
         when Files.Events.Scroll_Auto =>
            return Handle_Scroll (Model, Lines);
         when Files.Events.Scroll_Command_Palette =>
            if Files.Model.Command_Palette_Is_Open (Model) then
               if Files.Model.Palette_Result_Count (Model) = 0 then
                  return Make_Result (Controller_Ignored);
               else
                  Scroll_Palette_Selection (Model, Lines);
                  return Make_Result (Controller_Palette_Updated);
               end if;
            end if;
         when Files.Events.Scroll_Info_Pane =>
            if Files.Model.Info_Pane_Is_Open (Model) then
               return Scroll_Info_Result (Model, Lines);
            end if;
         when Files.Events.Scroll_Settings_Pane =>
            if Files.Model.Settings_Pane_Is_Open (Model) then
               return Scroll_Settings_Result (Model, Lines);
            end if;
         when Files.Events.Scroll_Main_View =>
            return Scroll_Main_Result (Model, Lines);
      end case;

      return Make_Result (Controller_Ignored);
   end Handle_Targeted_Scroll;
