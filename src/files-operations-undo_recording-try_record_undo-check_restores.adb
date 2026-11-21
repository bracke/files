separate (Files.Operations.Undo_Recording.Try_Record_Undo)
procedure Check_Restores is
begin
   for Index in Restores.First_Index .. Restores.Last_Index loop
      if Replaced (Index).Provenance = Files.Undo.History.Captured then
         declare
            Original : Files.Undo.History.Replaced_Original renames Restores (Index);
         begin
            Original.Target :=
              To_Unbounded_String (Files.File_System.Trash.Trash_Original_Path (To_String (Original.Trash)));
            Original.Identity := To_Unbounded_String (Files.File_Identities.Token (To_String (Original.Trash)));
         end;
      end if;
   end loop;
   if not Restores.Is_Empty and then Redoable then
      Invalid_Restore := True;
   end if;

   for Index in Restores.First_Index .. Restores.Last_Index loop
      if Length (Restores (Index).Target) = 0
        or else Length (Restores (Index).Identity) = 0
        or else (not Restore_Was_Verified (Index)
          and then not Identity_Matches
            (To_String (Restores (Index).Trash), To_String (Restores (Index).Identity)))
      then
         Invalid_Restore := True;
      end if;
   end loop;
end Check_Restores;
