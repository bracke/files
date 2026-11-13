separate (Files.Operations)
function Change_Recorded_Mode
  (Action : Files.Model.Undo_Entry; Index : Positive; Mode : Natural; Access_Text : String := "") return Boolean
is
   Previous : Natural;
   Identity : Files.Types.UString;
   Unused_Previous_Access, Unused_Applied_Access : Files.Types.UString;
begin
   if Files.Model.Created_Identity (Action, Index) = "" then
      return False;
   end if;
   return Files.File_System.Change_Access
     (To_String (Action.From (Index)), Files.Model.Created_Identity (Action, Index),
      Mode, Access_Text, Previous, Unused_Previous_Access, Unused_Applied_Access, Identity).Success;
end Change_Recorded_Mode;
