separate (Files.Controller.Handle_Key)
--  The file grid's own navigation keys, with nothing focused and the
--  settings pane closed: plain Home and End select the first and the last
--  visible item (no modifier, so never Alt+Home = navigate home), and Page
--  Up and Page Down page the selection -- or, with the info pane open,
--  scroll that. The arrows reach the grid as a Selection_Input_Action
--  (Files.Events.Translate_Key), which Shift extends.
procedure Grid_Key (Handled : out Boolean; Result : out Controller_Result) is

   --  How many lines Page Up or Page Down scrolls the info pane.
   Info_Pane_Page_Lines : constant := 10;

   Navigation : constant Files.Input_Actions.Grid_Navigation := Files.Input_Actions.Grid_Navigation_Of (Key);
begin
   Handled := False;
   Result := Make_Result (Controller_Ignored);
   if Modifiers /= Guikit.Input.No_Modifiers
     or else Files.Model.Focus (Model) /= Files.UI_Types.Focus_None
     or else Files.Model.Settings_Pane.Is_Open (Model)
     or else Navigation.Move in Files.Input_Actions.No_Grid_Move | Files.Input_Actions.Grid_Step
   then
      return;
   end if;
   Handled := True;
   if Navigation.Move in Files.Input_Actions.Grid_Page_Up | Files.Input_Actions.Grid_Page_Down
     and then Files.Model.Info_Pane_Is_Open (Model)
   then
      Result := Scroll_Result
        (Model, Files.Input_Actions.Scroll_Info_Pane,
         (if Navigation.Move = Files.Input_Actions.Grid_Page_Up then -Info_Pane_Page_Lines
          else Info_Pane_Page_Lines));
   else
      Result := Selection_Result (Model, Navigation);
   end if;
end Grid_Key;
