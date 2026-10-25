separate (Files.Events.Translate_Click)
--  The info pane: its close button and the permission and ownership grids.
procedure Info_Pane_Click (Handled : out Boolean; Result : out Input_Action) is
begin
   Handled := True;
   if Snapshot.Info_Pane_Open
     and then Close_Button_Hit
       (Info_Pane.X,
        Info_Pane.Y,
        (if Info_Pane.Scrollbar_Visible and then Info_Pane.Width > Info_Pane.Scrollbar_Width
         then Info_Pane.Width - Info_Pane.Scrollbar_Width
         else Info_Pane.Width),
        Info_Pane.Height)
   then
      Result := Command_Action (Files.Commands.Toggle_Info_Pane_Command, Activate);
      return;
   end if;

   if Snapshot.Info_Pane_Open and then Snapshot.Permissions_Editable then
      declare
         Cell : constant Files.Rendering.Permission_Hit_Region :=
           Files.Rendering.Hit.Permission_Hit_At (Frame, X, Y);
      begin
         if Cell.Present then
            Result :=
              (Kind       => Permission_Toggle_Input_Action,
               Item_Index => Cell.Bit,
               others     => <>);
            return;
         end if;
      end;
   end if;

   if Snapshot.Info_Pane_Open and then Snapshot.Ownership_Editable then
      declare
         Cell : constant Files.Rendering.Ownership_Hit_Region :=
           Files.Rendering.Hit.Ownership_Hit_At (Frame, X, Y);
      begin
         if Cell.Present then
            Result :=
              (Kind       => Ownership_Edit_Input_Action,
               Item_Index => (if Cell.Is_Group then 1 else 0),
               others     => <>);
            return;
         end if;
      end;
   end if;
   Handled := False;
   Result := No_Action (Activate);
end Info_Pane_Click;
