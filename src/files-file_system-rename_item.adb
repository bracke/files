with Files.Name_Parts;
with Files.Text_Case;

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
         return Files.IO.Fs_Primitives.Entry_Exists (From_Path);
      end if;

      --  A no-op needs the same pathname, not merely the same inode: two
      --  hard links or two links to one target are separate directory entries.
      --  Keep the leaf comparison so a case-only rename reaches its own path.
      --  refusal-safe: a refused source is no no-op; the rename then decides
      return Files.IO.Fs_Primitives.Entry_Exists (From_Path)
        and then Files.IO.Fs_Primitives.Absolute_Name (From_Path) = Files.IO.Fs_Primitives.Absolute_Name (To_Path)
        and then Mutation_Leaf_Name (From_Path) = Mutation_Leaf_Name (To_Path);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         --  refusal-safe: a refused source is no no-op; the rename then decides
         return From_Path = To_Path and then Files.IO.Fs_Primitives.Entry_Exists (From_Path);
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
      return Files.IO.Fs_Primitives.Entry_Exists (To_Path)
        and then Files.IO.Fs_Primitives.Parent_Directory (From_Path)
                 = Files.IO.Fs_Primitives.Parent_Directory (To_Path)
        and then
          (if From_Identity /= "" then
             Files.File_Identities.Token (To_Path) = From_Identity
           else not Hostkit.Fs.Is_Link (From_Path)
             and then not Hostkit.Fs.Is_Link (To_Path)
             and then Hostkit.Metadata.Same_File (From_Path, To_Path))
        and then Files.Text_Case.Fold_Case (Mutation_Leaf_Name (From_Path))
                 = Files.Text_Case.Fold_Case (Mutation_Leaf_Name (To_Path))
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
   function Rename_Case_Only return Mutation_Result is separate;

   Parent : constant String := Parent_Directory (To_Path);
   Name   : constant String := Mutation_Leaf_Name (To_Path);

   function Rename_Recorded return Mutation_Result is separate;

begin
   Left_At := Null_Unbounded_String;
   Failure := Rename_Refused;
   Files.IO.Errors.Reset;
   if To_Path /= "" and then Leaf_Too_Long (Name, Parent) then
      --  Longer than the destination stores: refused before the disk is
      --  touched, as a new entry is, so every host reports it alike.
      return
        (Success   => False,
         Error_Key => To_Unbounded_String (Files.IO.Errors.Name_Too_Long_Key));
   elsif Expected_Identity /= "" then
      return Rename_Recorded;
   --  refusal-safe: a refused source fails the rename
   elsif not Files.IO.Fs_Primitives.Entry_Exists (From_Path) then
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
   elsif (Files.IO.Fs_Primitives.Entry_Exists (To_Path) and then not Is_Case_Only_Rename)
     or else Parent = ""
     or else not Files.IO.Fs_Primitives.Directory_Exists (Parent)
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

   --  A refusal a copy would meet too (permission, busy, vanished source,
   --  occupied target) is no copy and delete. A rename cannot move across
   --  filesystems (EXDEV): that one falls back to copy + delete, as
   --  Execute_Drop_Import and Move_To_Trash do, so a cross-device move --
   --  and, crucially, the undo of one (Move_Back routes through here) --
   --  still succeeds instead of failing and stranding the file at the
   --  destination.
   declare
      Route : Recovery.Move_Route;
      Copied_Identity, Copied_Tree_Revision : UString;
      Copy_Kept : Boolean;
   begin
      return Recovery.Move_Or_Copy
        (From_Path, To_Path, "error.rename.failed", Route, Copied_Identity, Copied_Tree_Revision, Copy_Kept);
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return
        (Success   => False,
         Error_Key => Files.IO.Errors.Error_Key ("error.rename.failed"));
end Rename_Item;
