with Files.Command_Reasons;

separate (Files.Operations.Navigation)
--  History navigation shared by Navigate_Back and Navigate_Forward: mirror
--  images differing only in the availability check, the error key and the move.
--  The folder is read before the window moves, as Load_And_Navigate does: a
--  read that fails leaves the window as it was -- its view, its history, an
--  item being named, a refresh it owes -- with only the error line set, and
--  one that succeeds moves and shows the folder at once (the error line,
--  a search notice included, belonged to the view left and goes).
function Navigate_History
  (Model     : in out Files.Model.Window_Model;
   Settings  : Files.Settings.Settings_Model;
   Direction : History_Direction)
   return Operation_Result
is
   Available : constant Boolean :=
     (if Direction = History_Back
      then Files.Model.Can_Go_Back (Model)
      else Files.Model.Can_Go_Forward (Model));
   --  The key the disabled Back/Forward command reports, not a copy of it.
   Error_Key : constant String :=
     Files.Command_Reasons.Reason_Key
       (if Direction = History_Back
        then Files.Command_Reasons.Back_Unavailable_Reason
        else Files.Command_Reasons.Forward_Unavailable_Reason);
begin
   if not Available then
      return Disabled (Model, Error_Key);
   end if;

   declare
      Target : constant String :=
        (if Direction = History_Back
         then Files.Model.Back_Target (Model)
         else Files.Model.Forward_Target (Model));
      Load   : constant Files.File_System.Directory_Load_Result := Support.Load_Folder (Settings, Target);
   begin
      if not Load.Success then
         Files.Model.Set_Error (Model, To_String (Load.Error_Key));
         return Make_Result (Operation_Failed, To_String (Load.Error_Key), Target);
      end if;

      if Direction = History_Back then
         Files.Model.Go_Back (Model);
      else
         Files.Model.Go_Forward (Model);
      end if;
      Files.Model.Replace_Items (Model, Load.Items);
      Support.Show_Loaded_Folder (Model, Load);
      return Make_Result (Operation_Navigated, Path => Target);
   end;
end Navigate_History;
