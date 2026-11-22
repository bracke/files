with Files.Name_Parts;

separate (Files.File_System.Recovery_Registry)
function Release_Recovery_Payload (Path : String) return Mutation_Result is
   --  The Recycle Bin and the macOS Trash record where an item was when
   --  it was trashed, and put it back there: from the hidden stage that
   --  would be a hidden folder. So it goes back beside its original
   --  first, under that name or a free "name N" one, and is trashed from
   --  there. If the trash then refuses it and it cannot go back to the
   --  stage, it stays there -- in its own folder, not lost.
   function Natively (Entry_Path, Original : String) return Mutation_Result is
      Ignored   : Files.Types.UString;
      Directory : constant String := Files.IO.Fs_Primitives.Parent_Directory (Original);
      Leaf      : constant String := Files.Name_Parts.Leaf_Of (Original);
      Is_Folder : constant Boolean := Files.IO.Fs_Primitives.Is_Plain_Directory (Entry_Path);
      Limit     : constant Hostkit.Fs.Leaf_Name_Limit := Hostkit.Fs.Leaf_Name_Limit_At (Directory);
   begin
      --  The name a paste would give it there: "name", "name 2", ... Each
      --  try is the move itself, which refuses an occupied name; a move
      --  refused for any other reason (the folder is gone, or will not be
      --  written) is not tried under another name.
      for Attempt in 1 .. Files.Leaf_Names.Max_Attempts loop
         declare
            Beside : constant String :=
              Hostkit.Fs.Join
                (Directory,
                 Files.Leaf_Names.Candidate
                   (Files.Name_Parts.Name_Stem (Leaf, Is_Folder), Files.Name_Parts.Name_Extension (Leaf, Is_Folder),
                    Files.Leaf_Names.Spaced_Number (Attempt), Limit));
         begin
            if Support.Move_No_Replace (Entry_Path, Beside) then
               declare
                  Trashed : constant Mutation_Result := Trash.Move_To_Trash (Beside, Ignored);
               begin
                  if Trashed.Success or else not Support.Move_No_Replace (Beside, Entry_Path) then
                     return (Success => True, Error_Key => Null_Unbounded_String);
                  end if;
                  return Trashed;
               end;
            end if;
            --  refusal-safe: only a name surely in use is passed over; one
            --  that cannot be looked at ends the search, and the payload is
            --  trashed from its stage below.
            exit when not Files.IO.Fs_Primitives.Entry_Exists (Beside);
         end;
      end loop;
      return Trash.Move_To_Trash (Entry_Path, Ignored);
   end Natively;

   function To_Trash (Entry_Path, Original : String) return Mutation_Result is
      Ignored : Files.Types.UString;
   begin
      if Original /= ""
        and then Trash.Trash_Backend_Of_Current_Environment in Trash_Windows_Recycle_Bin | Trash_Macos_Native
      then
         return Natively (Entry_Path, Original);
      end if;
      return Trash.Move_To_Trash (Entry_Path, Ignored, Recorded_Path => Original);
   end To_Trash;
begin
   return Recovery.Release (Path, To_Trash'Access);
end Release_Recovery_Payload;
