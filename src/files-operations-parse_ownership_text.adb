separate (Files.Operations)
function Parse_Ownership_Text
  (Text : String; User_Id, Group_Id : out Files.Types.Account_Id;
   User_Name, Group_Name : out Files.Types.UString) return Boolean
is
   Value  : Files.Undo_Payloads.Ownership;
   Parsed : constant Boolean := Files.Undo_Payloads.Parse_Ownership (Text, Value);
begin
   User_Id := Value.User_Id;
   Group_Id := Value.Group_Id;
   User_Name := Value.User_Name;
   Group_Name := Value.Group_Name;
   return Parsed;
end Parse_Ownership_Text;
