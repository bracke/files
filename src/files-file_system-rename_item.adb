separate (Files.File_System)
function Rename_Item
  (From_Path : String;
   To_Path   : String;
   Expected_Identity : String := "")
   return Mutation_Result
is
   function Exists_Safely (Path : String) return Boolean is
   begin
      return Path /= "" and then
        (Files.Fs_Primitives.Exists (Path) or else Hostkit.Fs.Is_Link (Path));
   exception
      when others =>
         return False;
   end Exists_Safely;

   function Same_Existing_Path return Boolean is
   begin
      if From_Path = "" or else To_Path = "" then
         return False;
      end if;
      if From_Path = To_Path then
         return Exists_Safely (From_Path);
      end if;

      --  A no-op needs the same pathname, not merely the same inode: two
      --  hard links or two links to one target are separate directory entries.
      --  Keep the leaf comparison so a case-only rename reaches its own path.
      return Exists_Safely (From_Path)
        and then GNAT.OS_Lib.Normalize_Pathname (From_Path, Resolve_Links => False)
                 = GNAT.OS_Lib.Normalize_Pathname (To_Path, Resolve_Links => False)
        and then Mutation_Leaf_Name (From_Path) = Mutation_Leaf_Name (To_Path);
   exception
      when others =>
         return From_Path = To_Path and then Exists_Safely (From_Path);
   end Same_Existing_Path;

   --  A case-only rename of a single file: the destination exists but is the
   --  very same file as the source (a case-insensitive filesystem reports the
   --  two case-differing spellings as one file), and the leaves match only
   --  when case is ignored. This must NOT be treated as a collision.
   function Is_Case_Only_Rename return Boolean is
      From_Identity : constant String := Files.File_Identities.Token (From_Path);
   begin
      return Exists_Safely (To_Path)
        and then Ada.Directories.Containing_Directory (From_Path)
                 = Ada.Directories.Containing_Directory (To_Path)
        and then
          (if From_Identity /= "" then
             Files.File_Identities.Token (To_Path) = From_Identity
           else not Hostkit.Fs.Is_Link (From_Path)
             and then not Hostkit.Fs.Is_Link (To_Path)
             and then Hostkit.Metadata.Same_File (From_Path, To_Path))
        and then Files.Types.To_Lower (Mutation_Leaf_Name (From_Path))
                 = Files.Types.To_Lower (Mutation_Leaf_Name (To_Path))
        and then Mutation_Leaf_Name (From_Path) /= Mutation_Leaf_Name (To_Path);
   exception
      when others =>
         return False;
   end Is_Case_Only_Rename;

   --  Perform a case-only rename through a scratch name: From -> Temp -> To.
   --  On a case-insensitive filesystem the first hop frees the old spelling so
   --  the second lands on a now-vacant destination. Every hop refuses an
   --  occupied target; a failed second hop restores the original name when
   --  it remains free, otherwise it retains the owned entry at the scratch name.
   function Rename_Case_Only return Mutation_Result is
      function Temp_Candidate (Index : Natural) return String is
        (From_Path & ".files-case-rename-"
         & Ada.Strings.Fixed.Trim (Natural'Image (Index), Ada.Strings.Both));

      Temp : Unbounded_String := Null_Unbounded_String;
   begin
      for Index in 0 .. 4095 loop
         if not Exists_Safely (Temp_Candidate (Index)) then
            Temp := To_Unbounded_String (Temp_Candidate (Index));
            exit;
         end if;
      end loop;

      if Temp = Null_Unbounded_String then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.rename.failed"));
      end if;

      if not Support.Move_No_Replace (From_Path, To_String (Temp)) then
         return
           (Success   => False,
            Error_Key => Files.Io_Errors.Error_Key ("error.rename.failed"));
      end if;

      begin
         if not Support.Move_No_Replace (To_String (Temp), To_Path) then
            raise Ada.Directories.Use_Error;
         end if;
         return (Success => True, Error_Key => Null_Unbounded_String);
      exception
         when others =>
            declare
               --  Why the second hop failed, before the restore can say
               --  something else.
               Failed : constant Mutation_Result :=
                 (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.rename.failed"));
            begin
               --  Second hop failed: restore the original name if it is
               --  still free. A competing entry must never be overwritten.
               begin
                  declare
                     Restored : constant Boolean :=
                       Support.Move_No_Replace (To_String (Temp), From_Path);
                     pragma Unreferenced (Restored);
                  begin
                     null;
                  end;
               exception
                  when Swallowed : others =>
                     Files.Diagnostics.Note (Swallowed, "Files.File_System.Create");
               end;
               return Failed;
            end;
      end;
   exception
      when others =>
         --  A failed hop never overwrites a competing entry. The no-replace
         --  helper attempts to restore its source after a post-move error.
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.rename.failed"));
   end Rename_Case_Only;

   function Parent_Directory return String is
   begin
      return Ada.Directories.Containing_Directory (To_Path);
   exception
      when others =>
         return "";
   end Parent_Directory;

   Parent : constant String := Parent_Directory;
   Name   : constant String := Mutation_Leaf_Name (To_Path);

   function Rename_Recorded return Mutation_Result is
      Backup : UString;
      Failed : constant Mutation_Result :=
        (Success => False, Error_Key => To_Unbounded_String ("error.rename.failed"));
      Committed : Boolean := False;

      --  Failed, or the cause Step was refused for when one is known.
      function Failed_By (Step : Mutation_Result) return Mutation_Result is
        (if Files.Io_Errors.Is_Cause_Key (Step.Error_Key) then Step else Failed);

      procedure Restore_Source is
         Restored : constant Mutation_Result := Recovery.Restore (To_String (Backup));
         pragma Unreferenced (Restored);
      begin
         null;
      end Restore_Source;
   begin
      if Files.File_Identities.Token (From_Path) /= Expected_Identity then
         return Failed;
      end if;
      if Same_Existing_Path then
         return (Success => True, Error_Key => Null_Unbounded_String);
      end if;
      declare
         Preserved : constant Mutation_Result := Recovery.Preserve (From_Path, Backup);
      begin
         if not Preserved.Success then
            return Failed_By (Preserved);
         end if;
      end;
      --  The source is now private. A substituted entry must be restored,
      --  never moved to the history target or deleted by a copy fallback.
      if Files.File_Identities.Token (To_String (Backup)) /= Expected_Identity then
         Restore_Source;
         return Failed;
      end if;
      declare
         Renamed : constant Mutation_Result := Rename_Item (To_String (Backup), To_Path);
      begin
         if not Renamed.Success then
            Restore_Source;
            return Failed_By (Renamed);
         end if;
      end;
      Committed := True;
      declare
         Stage : constant String := Ada.Directories.Containing_Directory (To_String (Backup));
         Removed : constant Mutation_Result := Delete_Permanently (Stage);
         pragma Unreferenced (Removed);
      begin
         if not Ada.Directories.Exists (Stage) and then not Hostkit.Fs.Is_Link (Stage) then
            Recovery.Unregister (To_String (Backup));
         end if;
      end;
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         if not Committed and then Length (Backup) > 0 then
            Restore_Source;
         end if;
         return (Success => Committed,
                 Error_Key => (if Committed then Null_Unbounded_String else Failed.Error_Key));
   end Rename_Recorded;

   --  Set once the rename was refused only by a device boundary or a
   --  filesystem without no-replace rename; nothing else may fall back.
   May_Copy : Boolean := False;
begin
   Files.Io_Errors.Reset;
   if Expected_Identity /= "" then
      return Rename_Recorded;
   end if;
   if not Exists_Safely (From_Path) then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.rename.source_missing"));
   elsif Same_Existing_Path then
      return (Success => True, Error_Key => Null_Unbounded_String);
   elsif To_Path = "" then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.rename.invalid_destination"));
   elsif not Storable_Leaf_Name_At (Name, Parent) then
      --  Only what the destination cannot hold: a move keeps a name another
      --  program created; a name the user types is checked by the caller.
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.name.invalid"));
   elsif (Exists_Safely (To_Path) and then not Is_Case_Only_Rename)
     or else Parent = ""
     or else not Ada.Directories.Exists (Parent)
     or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory
   then
      --  The destination exists as a genuinely distinct file (a case-only
      --  rename of the source onto itself is excluded), or its parent is
      --  missing or not a directory.
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.rename.invalid_destination"));
   end if;

   if Is_Case_Only_Rename then
      --  Same file, different leaf case: rename through a scratch name with
      --  no destructive fallback, rather than letting Ada.Directories.Rename
      --  raise on the existing destination and drop into the copy + delete
      --  path below.
      return Rename_Case_Only;
   end if;

   declare
      use type Hostkit.Fs.Move_Outcome;
      Outcome : constant Hostkit.Fs.Move_Outcome := Support.Move_No_Replace_Outcome (From_Path, To_Path);
   begin
      if Outcome = Hostkit.Fs.Moved then
         return (Success => True, Error_Key => Null_Unbounded_String);
      elsif not Support.Copy_May_Replace_Move (Outcome) then
         --  Refused for a reason a copy would meet too (permission, busy,
         --  vanished source, occupied target): no copy and delete.
         return
           (Success   => False,
            Error_Key => Files.Io_Errors.Error_Key ("error.rename.failed"));
      end if;
      May_Copy := True;
      raise Ada.Directories.Use_Error;
   end;
exception
   when others =>
      if not May_Copy then
         return
           (Success   => False,
            Error_Key => Files.Io_Errors.Error_Key ("error.rename.failed"));
      end if;
      --  A rename cannot move across filesystems (EXDEV). Fall
      --  back to copy + delete, exactly as Execute_Drop_Import and
      --  Move_To_Trash do, so a cross-device move -- and, crucially, the undo
      --  of one (Move_Back routes through here) -- still succeeds instead of
      --  failing and stranding the file at the destination.
      declare
         Expected : Support.Source_Snapshot;
         Copied_Identity, Copied_Tree_Revision : UString;

         --  On any failure once the copy has started, drop whatever it left at
         --  the destination so the source stays the single canonical copy: no
         --  partial tree stranded, and no duplicate if the source delete fails.
         procedure Discard_Destination is
            --  Against the revision published, so anything added to the
            --  copy since is never deleted.
            Removed : constant Mutation_Result := Delete_Created_Entry
              (To_Path, To_String (Copied_Identity), To_String (Copied_Tree_Revision));
            pragma Unreferenced (Removed);
         begin
            null;
         end Discard_Destination;
      begin
         Expected := Support.Snapshot (From_Path);
         Support.Copy_To_New_Path
           (From_Path, To_Path, Copied_Identity, Copied_Tree_Revision, Times => Expected.Times,
            Preserve_Ownership => True);

         declare
            Deleted : constant Mutation_Result := Recovery.Remove_Move_Source (From_Path, Expected);
         begin
            if not Deleted.Success then
               Discard_Destination;
               return Deleted;
            end if;
         end;

         return (Success => True, Error_Key => Null_Unbounded_String);
      exception
         when others =>
            declare
               --  Why the copy failed, before discarding it can say otherwise.
               Failed : constant Mutation_Result :=
                 (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.rename.failed"));
            begin
               Discard_Destination;
               return Failed;
            end;
      end;
end Rename_Item;
