separate (Files.Images)
procedure Safe_Free
  (Pointer : in out Interfaces.C.Strings.chars_ptr) is
begin
   if Pointer /= Interfaces.C.Strings.Null_Ptr then
      begin
         Interfaces.C.Strings.Free (Pointer);
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Images");
      end;
   end if;
end Safe_Free;
