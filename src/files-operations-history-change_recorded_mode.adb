separate (Files.Operations.History)
function Change_Recorded_Mode
  (Action : Files.Undo.History.Undo_Entry; Index : Positive; Mode : Natural; Access_Text : String := "") return Boolean
is
   Previous : Natural;
   Identity : Files.Types.UString;
   Unused_Previous_Access, Unused_Applied_Access : Files.Types.UString;
begin
   if To_String (Action.Items (Index).Identity) = "" then
      return False;
   end if;
   return Files.File_System.Permissions.Change_Access
     (To_String (Action.Items (Index).From), To_String (Action.Items (Index).Identity),
      Mode, Access_Text, Previous, Unused_Previous_Access, Unused_Applied_Access, Identity).Success;
end Change_Recorded_Mode;
