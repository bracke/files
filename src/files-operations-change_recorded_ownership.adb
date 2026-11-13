separate (Files.Operations)
function Change_Recorded_Ownership
  (Action : Files.Model.Undo_Entry; Index : Positive;
   User_Id, Group_Id : Files.Types.Account_Id;
   Owner_Name, Group_Name : String) return Boolean
is
   Previous_User, Previous_Group : Files.Types.Account_Id;
   Identity : Files.Types.UString;
begin
   if Files.Model.Created_Identity (Action, Index) = "" then
      return False;
   end if;
   return Files.File_System.Change_Ownership
     (To_String (Action.From (Index)), Files.Model.Created_Identity (Action, Index),
      User_Id, Group_Id, Previous_User, Previous_Group, Identity,
      Owner_Name, Group_Name).Success;
end Change_Recorded_Ownership;
