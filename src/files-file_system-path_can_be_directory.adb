separate (Files.File_System)
function Path_Can_Be_Directory (Path : String) return Boolean is
   Current : Unbounded_String := To_Unbounded_String (Path);
   Parent  : Unbounded_String;
begin
   if Path = "" then
      return False;
   end if;

   loop
      declare
         Value : constant String := To_String (Current);
      begin
         if Value = "" then
            return False;
         --  refusal-safe: an answer for the trash's availability only; the
         --  folders are made, and moved into, by steps refused on the same path.
         elsif Files.IO.Fs_Primitives.Exists (Value) then
            return Files.IO.Fs_Primitives.Directory_Exists (Value);
         end if;

         Parent := To_Unbounded_String (Files.IO.Fs_Primitives.Parent_Directory (Value));
         if To_String (Parent) = Value then
            return False;
         end if;
         Current := Parent;
      end;
   end loop;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return False;
end Path_Can_Be_Directory;
