separate (Files_Suite.Rendering)
   procedure Test_Empty_Info_Pane_Message (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap    : View_Snapshot := Sample_Snapshot (3, Files.Types.Details);
      Message : constant String := Files.Localization.Text ("error.selection.empty");
      Found   : Boolean := False;
   begin
      Snap.Info_Pane_Open := True;
      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Snap, 640, 480, 20);
      begin
         for Command of Frame.Text loop
            if To_String (Command.Text) = Message then
               Found := True;
            end if;
         end loop;
      end;
      Assert (Found, "the empty information pane renders its localized empty-selection message");
   end Test_Empty_Info_Pane_Message;
