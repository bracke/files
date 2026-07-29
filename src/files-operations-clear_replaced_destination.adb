separate (Files.Operations)
   function Clear_Replaced_Destination
     (Path    : String;
      Source  : String;
      Trashed : out Files.Types.UString)
      return Boolean is
   begin
      Trashed := Null_Unbounded_String;
      if not Exists_Safely (Path) or else Path = Source then
         return True;
      end if;

      declare
         Result : constant Files.File_System.Mutation_Result :=
           Files.File_System.Move_To_Trash (Path, Trashed);
      begin
         if Result.Success then
            return True;
         end if;
      end;

      --  No trash backend available: fall back to a permanent delete, as before.
      --  Trashed stays empty, so such a replace is not undo-restorable (an existing
      --  limitation on trash-less environments, not made worse here).
      Trashed := Null_Unbounded_String;
      return Files.File_System.Delete_Permanently (Path).Success;
   end Clear_Replaced_Destination;
