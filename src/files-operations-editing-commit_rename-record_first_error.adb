separate (Files.Operations.Editing.Commit_Rename)
procedure Record_First_Error (Key : String; Path : String; Reason : Error_Reason := Other_Error) is
begin
   if First_Error_Key = Null_Unbounded_String then
      First_Error_Key := To_Unbounded_String (Key);
      First_Error_Path := To_Unbounded_String (Path);
      First_Error_Reason := Reason;
   end if;
end Record_First_Error;
