separate (Files.File_System)
function Release_Recovery_Payload (Path : String) return Mutation_Result is
   --  The Recycle Bin and the macOS Trash record where an item was when
   --  it was trashed, and put it back there: from the hidden stage that
   --  would be a hidden folder. So it goes back beside its original
   --  first, under that name or a free "name N" one, and is trashed from
   --  there. If the trash then refuses it and it cannot go back to the
   --  stage, it stays there -- in its own folder, not lost.
   function Natively (Entry_Path, Original : String) return Mutation_Result is
      Ignored   : Files.Types.UString;
      Directory : constant String := Files.Fs_Primitives.Parent_Directory (Original);
      Leaf      : constant String := Files.Fs_Primitives.Leaf_Text (Original);
      Stem      : constant String := Files.Types.Stem_Of (Leaf);
      Extension : constant String :=
        (if Files.Types.Extension_Of (Leaf) = "" then "" else "." & Files.Types.Extension_Of (Leaf));
   begin
      for Attempt in 1 .. 99 loop
         declare
            Beside : constant String :=
              Hostkit.Fs.Join
                (Directory,
                 (if Attempt = 1 then Leaf
                  else Stem & " " & Files.Types.Natural_Text (Attempt) & Extension));
         begin
            if Support.Move_No_Replace (Entry_Path, Beside) then
               declare
                  Trashed : constant Mutation_Result := Move_To_Trash (Beside, Ignored);
               begin
                  if Trashed.Success or else not Support.Move_No_Replace (Beside, Entry_Path) then
                     return (Success => True, Error_Key => Null_Unbounded_String);
                  end if;
                  return Trashed;
               end;
            end if;
         end;
      end loop;
      return Move_To_Trash (Entry_Path, Ignored);
   end Natively;

   function To_Trash (Entry_Path, Original : String) return Mutation_Result is
      Ignored : Files.Types.UString;
   begin
      if Original /= ""
        and then Trash_Backend_Of_Current_Environment in Trash_Windows_Recycle_Bin | Trash_Macos_Native
      then
         return Natively (Entry_Path, Original);
      end if;
      return Move_To_Trash (Entry_Path, Ignored, Recorded_Path => Original);
   end To_Trash;
begin
   return Recovery.Release (Path, To_Trash'Access);
end Release_Recovery_Payload;
