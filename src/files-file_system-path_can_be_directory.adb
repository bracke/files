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
            elsif Ada.Directories.Exists (Value) then
               return Ada.Directories.Kind (Value) = Ada.Directories.Directory;
            end if;

            Parent := To_Unbounded_String (Ada.Directories.Containing_Directory (Value));
            if To_String (Parent) = Value then
               return False;
            end if;
            Current := Parent;
         end;
      end loop;
   exception
      when others =>
         return False;
   end Path_Can_Be_Directory;
