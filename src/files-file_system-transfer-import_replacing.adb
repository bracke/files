separate (Files.File_System.Transfer)
function Import_Replacing
  (Source, Destination   : String;
   Mode                  : Drop_Import_Mode;
   Replace               : Boolean;
   Replaced              : out Files.Types.UString;
   Replaced_Identity     : out Files.Types.UString;
   Created_Identity      : out Files.Types.UString;
   Created_Tree_Revision : out Files.Types.UString;
   Preserved             : access procedure (Backup, Backup_Identity : String) := null;
   Cancel                : Cancellation_Check := Job_Cancelled;
   Batch                 : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
   return Mutation_Result
is
   Plans   : Drop_Import_Plan_Vectors.Vector;
   Created : Created_Entry_Vectors.Vector;
   Result  : Mutation_Result;
   --  Destination is Source, spelled differently or not (Is_Source).
   Self    : Boolean;

   --  The import failed after the original was preserved: put it back, so a
   --  failed replace never loses the entry it was to replace. A failed
   --  restore is the action's failure, and Replaced still names the original.
   procedure Roll_Back is
   begin
      Put_Back_Replaced (Replaced, Replaced_Identity, Destination, Result);
   end Roll_Back;

   --  Whether Destination is Source itself, however the two are spelled (a
   --  symlinked folder, another letter case on a case-folding volume, a
   --  trailing separator): the same entry in the same folder under the same
   --  name. Another hard link to Source is a different entry.
   function Is_Source return Boolean is
      Source_Token : constant String := Files.File_Identities.Token (Source);
      --  The folders as resolved: a linked folder is the folder it names.
      Source_Parent : constant String :=
        Files.IO.Fs_Primitives.Real_Name (Files.IO.Fs_Primitives.Parent_Directory (Source));
      Destination_Parent : constant String :=
        Files.IO.Fs_Primitives.Real_Name (Files.IO.Fs_Primitives.Parent_Directory (Destination));
   begin
      if Source = Destination then
         return True;
      end if;
      return Source_Token /= ""
        and then Source_Token = Files.File_Identities.Token (Destination)
        and then Source_Parent /= ""
        and then Destination_Parent /= ""
        and then Files.File_Identities.Token (Source_Parent) /= ""
        and then Files.File_Identities.Token (Source_Parent) = Files.File_Identities.Token (Destination_Parent)
        and then Files.Text_Case.Fold_Case (Files.Name_Parts.Leaf_Of (Source))
                 = Files.Text_Case.Fold_Case (Files.Name_Parts.Leaf_Of (Destination));
   end Is_Source;
begin
   Replaced := Null_Unbounded_String;
   Replaced_Identity := Null_Unbounded_String;
   Created_Identity := Null_Unbounded_String;
   Created_Tree_Revision := Null_Unbounded_String;
   --  A target that vanished since planning leaves nothing to preserve, and
   --  a destination that is the source is the entry being pasted.
   --  A destination that cannot be looked at is preserved like one that is
   --  there: preserving it fails, and nothing is imported over it.
   Self := not Files.IO.Fs_Primitives.Entry_Is_Absent (Destination) and then Is_Source;
   if Replace and then not Files.IO.Fs_Primitives.Entry_Is_Absent (Destination) and then not Self then
      Result := Recovery_Registry.Preserve_For_Replace (Destination, Replaced);
      if Length (Replaced) > 0 then
         Replaced_Identity := To_Unbounded_String (Files.File_Identities.Token (To_String (Replaced)));
         if Preserved /= null then
            Preserved.all (To_String (Replaced), To_String (Replaced_Identity));
         end if;
      end if;
      if not Result.Success then
         --  Nothing was imported; an original still held where Replaced
         --  names stays there for the caller to record.
         return Result;
      end if;
   end if;
   Plans.Append
     (Drop_Import_Plan'
        (Source_Path      => To_Unbounded_String (Source),
         --  Source itself under another spelling is imported as Source
         --  onto itself: a copy refuses it (error.drop.into_self), a move
         --  leaves it where it is.
         Destination_Path => To_Unbounded_String (if Self then Source else Destination),
         Mode             => Mode,
         Valid            => True,
         Error_Key        => Null_Unbounded_String));
   Result := Execute_Drop_Import (Plans, Created, Cancel, Batch);
   if not Created.Is_Empty then
      Created_Identity := Created.First_Element.Identity;
      Created_Tree_Revision := Created.First_Element.Tree_Revision;
   end if;
   --  A failure that still published a copy (a cross-device move that had
   --  to keep it) holds Destination: the original cannot go back there, and
   --  stays held at Replaced for the caller to record beside the copy.
   if not Result.Success and then Created.Is_Empty then
      Roll_Back;
   end if;
   return Result;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      Result := (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
      Roll_Back;
      return Result;
end Import_Replacing;
