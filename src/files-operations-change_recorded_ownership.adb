separate (Files.Operations)
function Change_Recorded_Ownership
  (Action : Files.Undo_History.Undo_Entry; Index : Positive; Owner : Files.Undo_Payloads.Ownership) return Boolean
is
   Previous_User, Previous_Group : Files.Types.Account_Id;
   Identity : Files.Types.UString;
begin
   if To_String (Action.Items (Index).Identity) = "" then
      return False;
   end if;
   return Files.File_System.Permissions.Change_Ownership
     (To_String (Action.Items (Index).From), To_String (Action.Items (Index).Identity),
      Owner.User_Id, Owner.Group_Id, Previous_User, Previous_Group, Identity,
      To_String (Owner.User_Name), To_String (Owner.Group_Name)).Success;
end Change_Recorded_Ownership;
