with Files.Name_Parts;

separate (Files.File_System)
function Restore_From_Trash_Backend
  (Trashed_Path : String; Expected_Identity : String := ""; Expected_Original : String := "")
   return Mutation_Result
is
   --  The home trash or the volume trash that holds it.
   Base      : constant String := Trash_Base_Of (Trashed_Path);

   --  An item in the Recycle Bin goes back as Explorer's Restore puts it:
   --  to the path its $I record names (or the one history recorded), never
   --  over anything that has taken its place.
   function From_Recycle_Bin return Mutation_Result is
      Item : Hostkit.Trash.Recycle_Bin_Entry;
   begin
      if not Hostkit.Trash.Entry_Of (Trashed_Path, Item) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_unavailable"));
      end if;
      declare
         Original : constant String :=
           (if Expected_Original /= "" then Expected_Original else To_String (Item.Original_Path));
      begin
         if not Valid_Original_Path (Original) then
            return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
         --  refusal-safe: the Recycle Bin's restore never replaces
         --  (Restore_Taken), so an original not seen is not written over.
         elsif Files.IO.Fs_Primitives.Entry_Exists (Original) then
            return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_exists"));
         elsif Expected_Identity /= ""
           and then Files.File_Identities.Token (Trashed_Path) /= Expected_Identity
         then
            --  Undo names the item it trashed; another under its $R name is
            --  not restored in its place.
            return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
         end if;
         case Hostkit.Trash.Restore (Trashed_Path, Original) is
            when Hostkit.Trash.Restored =>
               return (Success => True, Error_Key => Null_Unbounded_String);
            when Hostkit.Trash.Restore_Taken =>
               return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_exists"));
            when Hostkit.Trash.Restore_Not_In_Bin | Hostkit.Trash.Restore_Unsupported =>
               return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_unavailable"));
            when Hostkit.Trash.Restore_Failed =>
               return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
         end case;
      end;
   end From_Recycle_Bin;
begin
   Files.IO.Errors.Reset;
   if Trash_Backend_Of_Current_Environment = Trash_Windows_Recycle_Bin then
      return From_Recycle_Bin;
   end if;
   if Base = "" then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.trash.restore_unavailable"));
   end if;

   declare
      Simple    : constant String := Files.Name_Parts.Leaf_Of (Trashed_Path);
      Info_Path : constant String :=
        Trash_Info_Path (Base, Simple);
      Original  : Unbounded_String;
      Parent    : Unbounded_String;
      --  What the trash holds now, so what is removed once the item is back
      --  is this item and its own info file: the trash may be emptied, and
      --  another item trashed under the same name, while a long copy runs.
      Info_Identity : constant String := Files.File_Identities.Token (Info_Path);
   begin
      --  refusal-safe: an info file not seen refuses the restore.
      if Expected_Original = "" and then not Files.IO.Fs_Primitives.Exists (Info_Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_unavailable"));
      end if;

      Original := To_Unbounded_String
        (if Expected_Original /= "" then Expected_Original else Original_Path (Trashed_Path));
      if not Valid_Original_Path (To_String (Original)) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
      end if;

      Parent := To_Unbounded_String (Files.IO.Fs_Primitives.Parent_Directory (To_String (Original)));
      if To_String (Parent) = ""
        or else not Files.IO.Fs_Primitives.Directory_Exists (To_String (Parent))
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_parent_missing"));
      end if;

      --  refusal-safe: the move and the copy below never replace, so an
      --  original not seen is not written over.
      if Files.IO.Fs_Primitives.Entry_Exists (To_String (Original)) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_exists"));
      end if;

      --  Undo names the item it trashed: something else under that name now
      --  is not restored in its place. Then the same move a plain restore
      --  makes, across devices too.
      if Expected_Identity /= ""
        and then Files.File_Identities.Token (Trashed_Path) /= Expected_Identity
      then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
      end if;
      --  A rename refused for a reason a copy would meet too (the name was
      --  taken meanwhile, no permission) is no copy. When the trash is on
      --  another device it is the move by copy every move uses (copied into
      --  a private stage on the destination's filesystem, journaled,
      --  published without replacing), so a failed copy leaves Original
      --  absent. Cancellation stops new work, but must not interrupt a
      --  restore, which is recovery. Once the copy is on the device the
      --  restore is done. Only the item that was copied then leaves the
      --  trash, checked by identity and content as it is removed: one that
      --  is not it, or cannot be synced or removed, stays with its info file
      --  (Keep_Both), so it is still listed in the trash rather than hidden
      --  there for good, or someone else's lost.
      declare
         Route : Recovery.Move_Route;
         Identity, Revision : UString;
         Copy_Kept : Boolean;
         Moved     : constant Mutation_Result :=
           Recovery.Move_Or_Copy
             (Trashed_Path, To_String (Original), "error.trash.restore_failed",
              Route, Identity, Revision, Copy_Kept,
              Cancel            => null,
              If_Source_Stays   => Recovery.Keep_Both,
              After_Copy        => After_Restore_Copy,
              Expected_Identity => Expected_Identity);
      begin
         if Copy_Kept then
            return (Success => True, Error_Key => Null_Unbounded_String);
         elsif not Moved.Success then
            return Moved;
         end if;
      end;

      --  Its own info file only: one written for another item since, under
      --  the same name, stays.
      begin
         if Info_Identity /= "" and then Files.File_Identities.Token (Info_Path) = Info_Identity then
            Files.IO.Fs_Primitives.Delete_File (Info_Path);
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System");
      end;

      return (Success => True, Error_Key => Null_Unbounded_String);
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return
        (Success   => False,
         Error_Key => Files.IO.Errors.Error_Key ("error.trash.restore_failed"));
end Restore_From_Trash_Backend;
