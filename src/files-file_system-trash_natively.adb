separate (Files.File_System)
function Trash_Natively
  (Request : Native_Trash_Request)
   return Native_Trash_Result
is
   Result : Native_Trash_Result := Evaluate_Native_Trash (Request);
begin
   --  Attempted stays False when the evaluation refuses, so a caller can
   --  tell "we tried and it refused" from "there was nothing here to try".
   if not Result.Supported then
      return Result;
   end if;

   Result.Attempted := True;
   Result.Completed := Hostkit.Trash.Move_To_Trash (To_String (Request.Path));
   if not Result.Completed then
      Result.Error_Key := To_Unbounded_String ("error.trash.failed");
   end if;
   return Result;
end Trash_Natively;
