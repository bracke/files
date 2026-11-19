separate (Files.Controller)
   function Handle_Targeted_Scroll
     (Model  : in out Files.Model.Window_Model;
      Target : Files.Events.Scroll_Target;
      Lines  : Integer)
      return Controller_Result
   is
      Top     : Files.Model.Input_Overlay;
      Has_Top : constant Boolean := Files.Model.Topmost_Overlay (Model, Top);
   begin
      if Lines = 0 then
         return Make_Result (Controller_Ignored);
      end if;

      --  The overlay on top takes the wheel (Files.UI_Types.Overlay_Stack): a
      --  target that is not its own region is contained, as it contains
      --  clicks and character input. The folder-pick's own region is the tree.
      if Has_Top
        and then Target /=
          (case Top is
              when Files.UI_Types.Command_Palette_Overlay => Files.Events.Scroll_Command_Palette,
              when Files.UI_Types.Settings_Pane_Overlay   => Files.Events.Scroll_Settings_Pane,
              when Files.UI_Types.Tree_Pick_Overlay       => Files.Events.Scroll_Tree_Panel,
              when Files.UI_Types.Foreground_Job_Overlay
                 | Files.UI_Types.Paste_Conflict_Overlay
                 | Files.UI_Types.Root_Selector_Overlay
                 | Files.UI_Types.Sort_Menu_Overlay
                 | Files.UI_Types.Context_Menu_Overlay
                 | Files.UI_Types.Label_Picker_Overlay
                 | Files.UI_Types.Quick_Look_Overlay        => Files.Events.No_Scroll_Target)
      then
         return Make_Result (Controller_Ignored);
      end if;

      case Target is
         --  Not over any scrollable region: nothing moves.
         when Files.Events.No_Scroll_Target =>
            null;
         when Files.Events.Scroll_Command_Palette =>
            if Files.Model.Command_Palette.Is_Open (Model) then
               Files.Command_Palette.Ensure_Listed (Model);
               if Files.Model.Command_Palette.Result_Count (Model) = 0 then
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
         when Files.Events.Scroll_Tree_Panel =>
            if Files.Model.Tree_Panel.Is_Open (Model) then
               return Scroll_Tree_Result (Model, Lines);
            end if;
         when Files.Events.Scroll_Settings_Pane =>
            if Files.Model.Settings_Pane.Is_Open (Model) then
               return Scroll_Settings_Result (Model, Lines);
            end if;
         when Files.Events.Scroll_Main_View =>
            return Scroll_Main_Result (Model, Lines);
      end case;

      return Make_Result (Controller_Ignored);
   end Handle_Targeted_Scroll;
