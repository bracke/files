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
         elsif Files.Fs_Primitives.Entry_Exists (Original) then
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
   Files.Io_Errors.Reset;
   if Trash_Backend_Of_Current_Environment = Trash_Windows_Recycle_Bin then
      return From_Recycle_Bin;
   end if;
   if Base = "" then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.trash.restore_unavailable"));
   end if;

   declare
      Simple    : constant String := Files.Fs_Primitives.Leaf_Text (Trashed_Path);
      Info_Path : constant String :=
        Hostkit.Fs.Join (Hostkit.Fs.Join (Base, "info"), Simple & ".trashinfo");
      Original  : Unbounded_String;
      Parent    : Unbounded_String;
      --  What the trash holds now, so what is removed once the item is back
      --  is this item and its own info file: the trash may be emptied, and
      --  another item trashed under the same name, while a long copy runs.
      Info_Identity : constant String := Files.File_Identities.Token (Info_Path);
   begin
      if Expected_Original = "" and then not Files.Fs_Primitives.Exists (Info_Path) then
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

      Parent := To_Unbounded_String (Files.Fs_Primitives.Parent_Directory (To_String (Original)));
      if To_String (Parent) = ""
        or else not Files.Fs_Primitives.Directory_Exists (To_String (Parent))
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_parent_missing"));
      end if;

      if Files.Fs_Primitives.Entry_Exists (To_String (Original)) then
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
      declare
         use type Hostkit.Fs.Move_Outcome;
         Outcome : Hostkit.Fs.Move_Outcome := Hostkit.Fs.Move_Refused;
      begin
         begin
            Outcome := Support.Move_No_Replace_Outcome (Trashed_Path, To_String (Original));
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.File_System");
               Outcome := Hostkit.Fs.Move_Refused;
         end;
         if Outcome /= Hostkit.Fs.Moved and then not Support.Copy_May_Replace_Move (Outcome) then
            --  Refused for a reason a copy would meet too (the name was
            --  taken meanwhile, no permission): no copy.
            return (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.trash.restore_failed"));
         elsif Outcome /= Hostkit.Fs.Moved then
            declare
               Trashed_Identity : constant String := Files.File_Identities.Token (Trashed_Path);
               --  Its content too where the host gives it (none for a link):
               --  the item must not have changed while it was copied either.
               Trashed_Revision : constant String := Tree_Revision (Trashed_Path);
            begin
               --  The trash is on another device: the staged copy every move
               --  uses (copied into a private stage on the destination's
               --  filesystem, journaled, published without replacing), so a
               --  failed copy leaves Original absent. Cancellation stops new
               --  work, but must not interrupt a restore, which is recovery.
               declare
                  Identity, Revision : UString;
               begin
                  Support.Copy_To_New_Path
                    (Trashed_Path, To_String (Original), Identity, Revision,
                     Cancel => null, Preserve_Ownership => True, Durable => True);
               exception
                  when Swallowed : others =>
                     Files.Diagnostics.Note (Swallowed, "Files.File_System");
                     return
                       (Success   => False,
                        Error_Key => Files.Io_Errors.Error_Key ("error.trash.restore_failed"));
               end;
               if After_Restore_Copy /= null then
                  After_Restore_Copy (Trashed_Path);
               end if;
               --  The restore is done; the trash copy is now redundant once the
               --  restored copy is on the device. Only the item that was copied
               --  goes, checked by identity and content as it is removed: one
               --  that is not it, or cannot be synced or removed, stays with its
               --  info file, so it is still listed in the trash rather than
               --  hidden there for good, or someone else's lost.
               if Trashed_Identity = ""
                 or else not Support.Sync_Copy (Trashed_Path, To_String (Original), Files_Too => False)
                 or else not Delete_Verified_Entry
                   (Trashed_Path, Trashed_Identity, Trashed_Revision, Verify_Tree => Trashed_Revision /= "").Success
               then
                  return (Success => True, Error_Key => Null_Unbounded_String);
               end if;
            end;
         end if;
      end;

      --  Its own info file only: one written for another item since, under
      --  the same name, stays.
      begin
         if Info_Identity /= "" and then Files.File_Identities.Token (Info_Path) = Info_Identity then
            Files.Fs_Primitives.Delete_File (Info_Path);
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
         Error_Key => Files.Io_Errors.Error_Key ("error.trash.restore_failed"));
end Restore_From_Trash_Backend;
