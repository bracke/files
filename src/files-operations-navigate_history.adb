with Files.Commands;

separate (Files.Operations)
--  History navigation shared by Navigate_Back and Navigate_Forward: mirror
--  images differing only in the availability check, the error key and the move.
function Navigate_History
  (Model     : in out Files.Model.Window_Model;
   Settings  : Files.Settings.Settings_Model;
   Direction : History_Direction)
   return Operation_Result
is
   Had_Temporary  : constant Boolean := Files.Model.Temporary_Item_Is_Active (Model);
   Temporary_Name : constant String := Files.Model.Temporary_Item_Name (Model);
   Had_Rename     : constant Boolean := Files.Model.Rename_Is_Active (Model);
   Rename_Text    : constant String := Files.Model.Rename_Text (Model);
   Rename_Source  : constant String := Files.Model.Selected_Name (Model);
   Origin         : constant Files.Model.Navigation_Mark := Files.Model.Mark_Navigation (Model);
   Available      : constant Boolean :=
     (if Direction = History_Back
      then Files.Model.Can_Go_Back (Model)
      else Files.Model.Can_Go_Forward (Model));
   --  The key the disabled Back/Forward command reports, not a copy of it.
   Error_Key      : constant String :=
     Files.Commands.Reason_Key
       (if Direction = History_Back
        then Files.Commands.Back_Unavailable_Reason
        else Files.Commands.Forward_Unavailable_Reason);
begin
   if not Available then
      return Disabled (Model, Error_Key);
   end if;

   if Direction = History_Back then
      Files.Model.Go_Back (Model);
   else
      Files.Model.Go_Forward (Model);
   end if;
   Settle_Current_Is_Trash (Model);

   declare
      Reload : constant Operation_Result := Refresh (Model, Settings);
   begin
      if Reload.Status /= Operation_Success then
         --  Return to where the window was, then restore any interrupted
         --  rename/create.
         Files.Model.Return_To (Model, Origin);
         Settle_Current_Is_Trash (Model);
         if Had_Temporary then
            Files.Model.Begin_Create_File (Model, Temporary_Name);
         elsif Had_Rename then
            declare
               Selection_Restored : constant Boolean :=
                 Files.Model.Select_By_Name (Model, Rename_Source);
               pragma Unreferenced (Selection_Restored);
            begin
               null;
            end;
            Files.Model.Resume_Rename (Model, Rename_Text);
         end if;
      end if;

      return Reload;
   end;
end Navigate_History;
