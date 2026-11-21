separate (Files.File_System)
function Rename_Item
  (From_Path : String;
   To_Path   : String;
   Left_At   : out UString;
   Failure   : out Rename_Failure;
   Expected_Identity : String := "")
   return Mutation_Result
is
   function Same_Existing_Path return Boolean is
   begin
      if From_Path = "" or else To_Path = "" then
         return False;
      end if;
      if From_Path = To_Path then
         --  refusal-safe: a refused source is no no-op; the rename then decides
         return Files.Fs_Primitives.Entry_Exists (From_Path);
      end if;

      --  A no-op needs the same pathname, not merely the same inode: two
      --  hard links or two links to one target are separate directory entries.
      --  Keep the leaf comparison so a case-only rename reaches its own path.
      --  refusal-safe: a refused source is no no-op; the rename then decides
      return Files.Fs_Primitives.Entry_Exists (From_Path)
        and then Files.Fs_Primitives.Absolute_Name (From_Path) = Files.Fs_Primitives.Absolute_Name (To_Path)
        and then Mutation_Leaf_Name (From_Path) = Mutation_Leaf_Name (To_Path);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         --  refusal-safe: a refused source is no no-op; the rename then decides
         return From_Path = To_Path and then Files.Fs_Primitives.Entry_Exists (From_Path);
   end Same_Existing_Path;

   --  A case-only rename of a single file: the destination exists but is the
   --  very same file as the source (a case-insensitive filesystem reports the
   --  two case-differing spellings as one file), and the leaves match only
   --  when case and Unicode form are ignored -- in every script, not only
   --  Latin-1 (Привет to привет). This must NOT be treated as a collision.
   function Is_Case_Only_Rename return Boolean is
      From_Identity : constant String := Files.File_Identities.Token (From_Path);
   begin
      --  refusal-safe: a refused target is no case-only rename; the no-replace move refuses it
      return Files.Fs_Primitives.Entry_Exists (To_Path)
        and then Files.Fs_Primitives.Parent_Directory (From_Path)
                 = Files.Fs_Primitives.Parent_Directory (To_Path)
        and then
          (if From_Identity /= "" then
             Files.File_Identities.Token (To_Path) = From_Identity
           else not Hostkit.Fs.Is_Link (From_Path)
             and then not Hostkit.Fs.Is_Link (To_Path)
             and then Hostkit.Metadata.Same_File (From_Path, To_Path))
        and then Files.Types.Fold_Case (Mutation_Leaf_Name (From_Path))
                 = Files.Types.Fold_Case (Mutation_Leaf_Name (To_Path))
        and then Mutation_Leaf_Name (From_Path) /= Mutation_Leaf_Name (To_Path);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return False;
   end Is_Case_Only_Rename;

   --  Perform a case-only rename through a scratch name: From -> Temp -> To.
   --  On a case-insensitive filesystem the first hop frees the old spelling so
   --  the second lands on a now-vacant destination. Every hop refuses an
   --  occupied target; a failed second hop restores the original name when
   --  it remains free, otherwise it retains the owned entry at the scratch name
   --  and says where (Rename_Stranded_Key, Left_At).
   function Rename_Case_Only return Mutation_Result is
      Directory : constant String := Files.Fs_Primitives.Parent_Directory (From_Path);

      --  Beside the original and visible, named after it ("notes
      --  (renaming).txt"), so an entry left there is found by the name the
      --  user knows; the stem is cut so the name stays storable. Built like
      --  the duplicate's "(copy)" marker: a fixed, unlocalized file name,
      --  the same on every locale.
      function Marker (Attempt : Natural) return String is
        (Files.Leaf_Names.Counted_Marker ("renaming", Attempt));

      --  A name the host will not answer for raises (Is_Taken): the
      --  rename fails rather than move onto a name that may be in use.
      function Taken (Leaf : String) return Boolean is
        (Files.Fs_Primitives.Is_Taken (Hostkit.Fs.Join (Directory, Leaf)));

      Temp : Unbounded_String := Null_Unbounded_String;

      --  Whether the entry is left at the scratch name.
      --  The scratch name was free when chosen, so an entry there is ours,
      --  whether or not something took the original name meanwhile.
      function Stranded return Boolean is
        (Temp /= Null_Unbounded_String and then not Files.Fs_Primitives.Entry_Is_Absent (To_String (Temp)));

      function Stranded_Result return Mutation_Result is
      begin
         Left_At := Temp;
         Failure := Rename_Stranded;
         return (Success => False, Error_Key => To_Unbounded_String (Rename_Stranded_Key));
      end Stranded_Result;
   begin
      begin
         declare
            Leaf      : constant String := Mutation_Leaf_Name (From_Path);
            Is_Folder : constant Boolean := Files.Fs_Primitives.Is_Plain_Directory (From_Path);
            Free      : constant String :=
              Files.Leaf_Names.First_Free
                (Files.Types.Name_Stem (Leaf, Is_Folder), Files.Types.Name_Extension (Leaf, Is_Folder),
                 Marker'Access, Taken'Access,
                 --  Asked once: the search may try thousands of names.
                 Hostkit.Fs.Leaf_Name_Limit_At (Directory));
         begin
            if Free /= "" then
               Temp := To_Unbounded_String (Hostkit.Fs.Join (Directory, Free));
            end if;
         end;
      exception
         when Refused : Ada.Directories.Use_Error =>
            --  A scratch name that could not be looked at: no rename.
            Files.Diagnostics.Note (Refused, "Files.File_System");
            Temp := Null_Unbounded_String;
      end;

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
         when Failure : others =>
            Files.Diagnostics.Note (Failure, "Files.File_System");
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
                     Files.Diagnostics.Note (Swallowed, "Files.File_System");
               end;
               --  Neither the new name nor the way back: say where it is.
               if Stranded then
                  return Stranded_Result;
               end if;
               return Failed;
            end;
      end;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         --  A failed hop never overwrites a competing entry. The no-replace
         --  helper attempts to restore its source after a post-move error;
         --  when that failed too, the entry is at the scratch name.
         if Stranded then
            return Stranded_Result;
         end if;
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.rename.failed"));
   end Rename_Case_Only;

   Parent : constant String := Parent_Directory (To_Path);
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
         Renamed : Mutation_Result := Failed;

         --  The payload leaves its stage for the history target, the stage
         --  marked first (Recovery.Vacate): a stop now leaves a stage the
         --  sweep finishes, not one kept for good.
         function Move_Out return Boolean is
         begin
            Renamed := Rename_Item (To_String (Backup), To_Path);
            return Renamed.Success;
         end Move_Out;

         Ran : Boolean;
      begin
         if not Recovery.Vacate (To_String (Backup), Move_Out'Access, Ran) then
            Restore_Source;
            return Failed_By (Renamed);
         end if;
      end;
      Committed := True;
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         if not Committed and then Length (Backup) > 0 then
            Restore_Source;
         end if;
         return (Success => Committed,
                 Error_Key => (if Committed then Null_Unbounded_String else Failed.Error_Key));
   end Rename_Recorded;

begin
   Left_At := Null_Unbounded_String;
   Failure := Rename_Refused;
   Files.Io_Errors.Reset;
   if To_Path /= "" and then Leaf_Too_Long (Name, Parent) then
      --  Longer than the destination stores: refused before the disk is
      --  touched, as a new entry is, so every host reports it alike.
      return
        (Success   => False,
         Error_Key => To_Unbounded_String (Files.Io_Errors.Name_Too_Long_Key));
   elsif Expected_Identity /= "" then
      return Rename_Recorded;
   --  refusal-safe: a refused source fails the rename
   elsif not Files.Fs_Primitives.Entry_Exists (From_Path) then
      Failure := Rename_Source_Missing;
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
      Failure := Rename_Name_Invalid;
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.name.invalid"));
   --  refusal-safe: a refused target passes on to the no-replace move, which refuses an occupied one
   elsif (Files.Fs_Primitives.Entry_Exists (To_Path) and then not Is_Case_Only_Rename)
     or else Parent = ""
     or else not Files.Fs_Primitives.Directory_Exists (Parent)
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

      --  A rename cannot move across filesystems (EXDEV). Fall
      --  back to copy + delete, exactly as Execute_Drop_Import and
      --  Move_To_Trash do, so a cross-device move -- and, crucially, the undo
      --  of one (Move_Back routes through here) -- still succeeds instead of
      --  failing and stranding the file at the destination.
      declare
         Copied_Identity, Copied_Tree_Revision : UString;
         Copy_Kept : Boolean;
      begin
         return Recovery.Move_By_Copy
           (From_Path, To_Path, "error.rename.failed", Copied_Identity, Copied_Tree_Revision, Copy_Kept);
      end;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return
        (Success   => False,
         Error_Key => Files.Io_Errors.Error_Key ("error.rename.failed"));
end Rename_Item;
