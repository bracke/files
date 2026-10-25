separate (Files.Operations)
function Change_Recorded_Ownership
  (Action : Files.Model.Undo_Entry; Index : Positive;
   User_Id, Group_Id : Files.Types.Account_Id;
   Owner_Name, Group_Name : String) return Boolean
is
   Previous_User, Previous_Group : Files.Types.Account_Id;
   Identity : Files.Types.UString;
begin
   if Index > Action.Created_Identities.Last_Index or else Length (Action.Created_Identities (Index)) = 0 then
      return False;
   end if;
   return Files.File_System.Change_Ownership
     (To_String (Action.From (Index)), To_String (Action.Created_Identities (Index)),
      User_Id, Group_Id, Previous_User, Previous_Group, Identity,
      Owner_Name, Group_Name).Success;
end Change_Recorded_Ownership;
