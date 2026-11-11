separate (Files.Operations)
function Change_Recorded_Mode
  (Action : Files.Model.Undo_Entry; Index : Positive; Mode : Natural; Access_Text : String := "") return Boolean
is
   Previous : Natural;
   Identity : Files.Types.UString;
   Unused_Previous_Access, Unused_Applied_Access : Files.Types.UString;
begin
   if Index > Action.Created_Identities.Last_Index or else Length (Action.Created_Identities (Index)) = 0 then
      return False;
   end if;
   return Files.File_System.Change_Access
     (To_String (Action.From (Index)), To_String (Action.Created_Identities (Index)),
      Mode, Access_Text, Previous, Unused_Previous_Access, Unused_Applied_Access, Identity).Success;
end Change_Recorded_Mode;
