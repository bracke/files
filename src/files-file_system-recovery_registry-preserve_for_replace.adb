separate (Files.File_System.Recovery_Registry)
function Preserve_For_Replace
  (Path : String; Recovery_Path : out Files.Types.UString) return Mutation_Result
is
   Result : Mutation_Result;
begin
   Recovery_Path := Null_Unbounded_String;
   --  Replacement must remain reversible.  Refuse before moving the
   --  original when this host cannot identify it, rather than publishing a
   --  new destination whose retained original cannot be safely restored.
   if Files.File_Identities.Token (Path) = "" then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.trash.failed"));
   end if;
   if Trash.Trash_Backend_Of_Current_Environment in Trash.Trash_Xdg_Data_Home | Trash.Trash_Home_Data then
      Result := Trash.Move_To_Trash (Path, Recovery_Path);
   else
      Result := Recovery.Preserve (Path, Recovery_Path);
   end if;

   if Result.Success
     and then
       (Length (Recovery_Path) = 0
        or else Files.File_Identities.Token (To_String (Recovery_Path)) = "")
   then
      if Length (Recovery_Path) > 0 then
         declare
            Restored : constant Mutation_Result :=
              Trash.Restore_From_Trash
                (To_String (Recovery_Path), Expected_Original => Path);
         begin
            if Restored.Success then
               Recovery_Path := Null_Unbounded_String;
            end if;
         end;
      end if;
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.trash.failed"));
   end if;
   return Result;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.trash.failed"));
end Preserve_For_Replace;
