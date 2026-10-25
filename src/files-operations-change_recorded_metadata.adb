separate (Files.Operations)
function Change_Recorded_Metadata
  (Action : Files.Model.Undo_Entry; Index : Positive; Ownership : Boolean;
   Value : Natural; Group : Natural := 0;
   Owner_Name : String := ""; Group_Name : String := "") return Boolean
is
   Previous, Previous_Group : Natural;
   Identity : Files.Types.UString;
begin
   if Index > Action.Created_Identities.Last_Index or else Length (Action.Created_Identities (Index)) = 0 then
      return False;
   end if;
   return Files.File_System.Change_Metadata
     (To_String (Action.From (Index)), To_String (Action.Created_Identities (Index)),
      Ownership, Value, Group, Previous, Previous_Group, Identity,
      Owner_Name, Group_Name).Success;
end Change_Recorded_Metadata;
