with Files.File_System.Support;
with Ada.Strings.Unbounded;
with Ada.Directories;
with Files.Fs;
with Files.Job_Context;
with Files.File_System.Recovery;
with Files.File_Identities;

separate (Files.File_System)
package body Copy_Move is

   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result is
   begin
      Support.Copy_To_New_Path (Source_Path, Destination_Path, Batch => Batch);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.copy.failed"));
   end Copy_Tree;

   function Copy_Tree
     (Source_Path, Destination_Path : String;
      Identity, Tree_Revision_Value : out Files.Types.UString;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result is
   begin
      Support.Copy_To_New_Path
        (Source_Path, Destination_Path, Identity, Tree_Revision_Value, Batch => Batch);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         Identity := Null_Unbounded_String;
         Tree_Revision_Value := Null_Unbounded_String;
         return (Success => False, Error_Key => To_Unbounded_String ("error.copy.failed"));
   end Copy_Tree;

   function Delete_Permanently
     (Path : String)
      return Mutation_Result
   is
      function Has_Navigation_Component return Boolean is
         First : Positive := Path'First;
      begin
         for Index in Path'Range loop
            if Path (Index) = '/' or else Path (Index) = '\' then
               if Index > First
                 and then Path (First .. Index - 1) in "." | ".."
               then
                  return True;
               end if;
               First := Index + 1;
            end if;
         end loop;
         return First <= Path'Last
           and then Path (First .. Path'Last) in "." | "..";
      end Has_Navigation_Component;

      function Unsafe_Target return Boolean is
      begin
         if Path = ""
           or else Path = "/"
           or else (Path'Length = 3 and then Path (Path'First + 1 .. Path'First + 2) = ":\")
           or else Has_Navigation_Component
         then
            return True;
         end if;

         if Hostkit.Fs.Is_Link (Path) then
            return False;
         end if;

         declare
            Full   : constant String := Ada.Directories.Full_Name (Path);
            Parent : constant String := Ada.Directories.Containing_Directory (Full);
         begin
            return Full = ""
              or else Full = Parent
              or else (Full'Length = 1 and then Full (Full'First) = '/');
         end;
      exception
         when others =>
            return True;
      end Unsafe_Target;
   begin
      if Unsafe_Target then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permanent_delete.refused"));
      elsif not (Ada.Directories.Exists (Path) or else Hostkit.Fs.Is_Link (Path)) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.rename.source_missing"));
      end if;

      --  Symlink-aware recursive delete: a symlink -- even one whose target is
      --  a directory -- is unlinked as a link and never followed, so deleting a
      --  link (or a folder that merely contains one) can never reach through
      --  into the link target's real contents. Ada.Directories.Delete_Tree,
      --  used previously via Files.Fs, follows links and would.
      Support.Delete_Tree (Path);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permanent_delete.failed"));
   end Delete_Permanently;

   function Plan_Drop_Import
     (Source_Paths          : Files.Types.String_Vectors.Vector;
      Destination_Directory : String;
      Mode                  : Drop_Import_Mode := Drop_Copy)
      return Drop_Import_Result
   is
      Result : Drop_Import_Result :=
        (Success   => False,
         Plans     => Drop_Import_Plan_Vectors.Empty_Vector,
         Error_Key => Null_Unbounded_String);
      --  Destinations already assigned earlier in this batch. They do not yet
      --  exist on disk, so without tracking them two sources sharing a simple
      --  name (from different directories) would resolve to the same target and
      --  the second would silently overwrite the first.
      Claimed : Files.Types.String_Vectors.Vector;

      function Image_No_Space (Value : Natural) return String is
         Image : constant String := Natural'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Image_No_Space;

      function Extension_Start (Name : String) return Natural is
      begin
         for Index in reverse Name'Range loop
            if Name (Index) = '.' and then Index > Name'First then
               return Index;
            end if;
         end loop;
         return 0;
      end Extension_Start;

      function Is_Claimed (Path : String) return Boolean is
      begin
         for Existing of Claimed loop
            if To_String (Existing) = Path then
               return True;
            end if;
         end loop;
         return False;
      end Is_Claimed;

      function Available_Destination (Leaf : String) return String is
         Dot       : constant Natural := Extension_Start (Leaf);
         Stem      : constant String :=
           (if Dot = 0 then Leaf else Leaf (Leaf'First .. Dot - 1));
         Extension : constant String :=
           (if Dot = 0 then "" else Leaf (Dot .. Leaf'Last));
         Counter   : Positive := 2;
         Candidate : Unbounded_String := To_Unbounded_String (Leaf);
         Full      : Unbounded_String :=
           To_Unbounded_String (Join_Path (Destination_Directory, To_String (Candidate)));
      begin
         while (Ada.Directories.Exists (To_String (Full)) or else Hostkit.Fs.Is_Link (To_String (Full)))
           or else Is_Claimed (To_String (Full)) loop
            Candidate := To_Unbounded_String (Stem & " " & Image_No_Space (Counter) & Extension);
            Full := To_Unbounded_String (Join_Path (Destination_Directory, To_String (Candidate)));
            exit when Counter = Positive'Last;
            Counter := Counter + 1;
         end loop;
         return To_String (Full);
      end Available_Destination;

      --  True when Inner is Outer itself or a descendant of Outer (normalized).
      function Is_Within_Tree (Inner : String; Outer : String) return Boolean is
         I : constant String := Ada.Directories.Full_Name (Inner);
         O : constant String :=
           (if Hostkit.Fs.Is_Link (Outer) then GNAT.OS_Lib.Normalize_Pathname (Outer, Resolve_Links => False)
            else Ada.Directories.Full_Name (Outer));
      begin
         if Hostkit.Fs.Is_Link (Outer) then
            return False; --  Copying a link never traverses its target tree.
         end if;
         --  The boundary is whichever separator the host writes. This accepted
         --  only '/', and Full_Name spells a Windows path with '\', so no
         --  directory was ever inside its own tree there -- and dropping a folder
         --  into its own subfolder, which this exists to refuse, was allowed
         --  straight through into an unbounded recursive copy.
         return I = O
           or else (I'Length > O'Length
                    and then I (I'First .. I'First + O'Length - 1) = O
                    and then (I (I'First + O'Length) = '/'
                              or else I (I'First + O'Length) = '\'));
      end Is_Within_Tree;
   begin
      if not Files.Fs.Directory_Exists (Destination_Directory)
      then
         Result.Error_Key := To_Unbounded_String ("error.drop.invalid_destination");
         return Result;
      end if;

      for Source of Source_Paths loop
         declare
            Source_Text : constant String := To_String (Source);
            Leaf        : Unbounded_String;
            Plan        : Drop_Import_Plan;
         begin
            Plan.Source_Path := Source;
            Plan.Mode := Mode;
            if not (Ada.Directories.Exists (Source_Text) or else Hostkit.Fs.Is_Link (Source_Text)) then
               Plan.Valid := False;
               Plan.Error_Key := To_Unbounded_String ("error.drop.invalid_source");
               Result.Plans.Append (Plan);
               Result.Error_Key := Plan.Error_Key;
            else
               Leaf := To_Unbounded_String (Ada.Directories.Simple_Name (Source_Text));
               if not Valid_Leaf_Name_At (To_String (Leaf), Destination_Directory) then
                  Plan.Valid := False;
                  Plan.Error_Key := To_Unbounded_String ("error.name.invalid");
                  Result.Error_Key := Plan.Error_Key;
               elsif Is_Within_Tree (Destination_Directory, Source_Text) then
                  --  Refuse to copy or move a directory into itself or one of
                  --  its own descendants; Execute_Drop_Import's recursive copy
                  --  would otherwise recurse without bound.
                  Plan.Valid := False;
                  Plan.Error_Key := To_Unbounded_String ("error.drop.into_self");
                  Result.Error_Key := Plan.Error_Key;
               else
                  Plan.Valid := True;
                  if Mode = Drop_Move
                    and then Ada.Directories.Full_Name
                               (Ada.Directories.Containing_Directory (Source_Text))
                             = Ada.Directories.Full_Name (Destination_Directory)
                  then
                     --  Moving an item into the directory it already lives in is
                     --  a no-op; keep its own path so Execute_Drop_Import skips
                     --  it instead of creating a numbered duplicate. (A copy
                     --  into the same directory still makes a numbered copy.)
                     Plan.Destination_Path := Source;
                  else
                     Plan.Destination_Path := To_Unbounded_String (Available_Destination (To_String (Leaf)));
                  end if;
                  Claimed.Append (Plan.Destination_Path);
                  Plan.Error_Key := Null_Unbounded_String;
               end if;
               Result.Plans.Append (Plan);
            end if;
         exception
            when others =>
               Result.Plans.Append
                 (Drop_Import_Plan'
                    (Source_Path      => Source,
                     Destination_Path => Null_Unbounded_String,
                     Mode             => Mode,
                     Valid            => False,
                     Error_Key        => To_Unbounded_String ("error.drop.failed")));
               Result.Error_Key := To_Unbounded_String ("error.drop.failed");
         end;
      end loop;

      Result.Success := Length (Result.Error_Key) = 0;
      return Result;
   end Plan_Drop_Import;

   function Execute_Drop_Import
     (Plans  : Drop_Import_Plan_Vectors.Vector;
      Cancel : Cancellation_Check := null;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result
   is
      Identities, Tree_Revisions : Files.Types.String_Vectors.Vector;
   begin
      return Execute_Drop_Import (Plans, Identities, Tree_Revisions, Cancel, Batch);
   end Execute_Drop_Import;

   function Execute_Drop_Import
     (Plans  : Drop_Import_Plan_Vectors.Vector;
      Created_Identities, Created_Tree_Revisions : out Files.Types.String_Vectors.Vector;
      Cancel : Cancellation_Check := null;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result
   is
      Context : Files.Copy_Context.Session := Batch;
   begin
      Created_Identities.Clear;
      Created_Tree_Revisions.Clear;
      if Natural (Plans.Length) > 1 and then Files.Copy_Context.Directory (Context) = "" then
         Context := Files.Copy_Context.Create;
      end if;
      for Plan of Plans loop
         if not Plan.Valid then
            return
              (Success   => False,
               Error_Key =>
                 (if Length (Plan.Error_Key) > 0
                  then Plan.Error_Key
                  else To_Unbounded_String ("error.drop.failed")));
         end if;
      end loop;

      for Plan of Plans loop
         declare
            Source_Path      : constant String := To_String (Plan.Source_Path);
            Destination_Path : constant String := To_String (Plan.Destination_Path);
            Published_Identity, Published_Tree_Revision : UString;

         begin
            if Source_Path = Destination_Path and then Plan.Mode = Drop_Copy then
               return (Success => False, Error_Key => To_Unbounded_String ("error.drop.into_self"));
            end if;
            --  A destination may have appeared since planning. It belongs to
            --  someone else and must never be removed by failure cleanup.
            if Source_Path /= Destination_Path
              and then (Ada.Directories.Exists (Destination_Path)
                        or else Hostkit.Fs.Is_Link (Destination_Path))
            then
               return (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
            end if;
            if Cancel /= null and then Cancel.all then
               return (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
            end if;
            if Plan.Mode = Drop_Move then
               if Source_Path /= Destination_Path then
                  declare
                     Identity : constant String := Files.File_Identities.Token (Source_Path);
                  begin
                     if Support.Move_No_Replace (Source_Path, Destination_Path) then
                        --  The move is committed. Only a refused rename may use
                        --  the copy/delete fallback. A rename needs no content
                        --  snapshot: move recovery and Undo use the entry identity.
                        Published_Identity := To_Unbounded_String (Identity);
                        Published_Tree_Revision := Null_Unbounded_String;
                        Files.Job_Context.Record_Moved (Destination_Path, Source_Path, Identity);
                     else
                        declare
                           Expected : constant Support.Source_Snapshot := Support.Snapshot (Source_Path);
                           Copied_Identity, Copied_Tree_Revision : UString;
                        begin
                           Support.Copy_To_New_Path
                             (Source_Path, Destination_Path, Copied_Identity, Copied_Tree_Revision,
                              Cancel, Expected.Times,
                              Preserve_Ownership => True, Batch => Context);
                           declare
                              Delete_Result : constant Mutation_Result :=
                                Recovery.Remove_Move_Source (Source_Path, Expected);
                           begin
                              if not Delete_Result.Success then
                                 --  Source removal is atomic. A failure leaves it
                                 --  intact, so discard our complete copy and allow
                                 --  paste-replace to restore its original destination.
                                 declare
                                    Removed : constant Mutation_Result := Delete_Created_Entry
                                      (Destination_Path, To_String (Copied_Identity),
                                       Tree_Revision (Destination_Path));
                                    pragma Unreferenced (Removed);
                                 begin
                                    null;
                                 end;
                                 return Delete_Result;
                              end if;
                              Files.Job_Context.Record_Moved
                                (Destination_Path, Source_Path, To_String (Copied_Identity));
                              Published_Identity := Copied_Identity;
                              Published_Tree_Revision := Copied_Tree_Revision;
                           end;
                        end;
                     end if;
                  end;
               else
                  Published_Identity := To_Unbounded_String (Files.File_Identities.Token (Destination_Path));
                  Published_Tree_Revision := To_Unbounded_String (Tree_Revision (Destination_Path));
               end if;
            else
               Support.Copy_To_New_Path
                 (Source_Path, Destination_Path, Published_Identity, Published_Tree_Revision,
                  Cancel => Cancel, Batch => Context);
            end if;
            Created_Identities.Append (Published_Identity);
            Created_Tree_Revisions.Append (Published_Tree_Revision);
         exception
            when others =>
               --  A copy raised partway (e.g. out of space); remove the partial
               --  destination before reporting failure. The source is untouched.
               --  Copy_Tree cleans up only destinations it created.
               return
                 (Success   => False,
                  Error_Key => To_Unbounded_String ("error.drop.failed"));
         end;
      end loop;

      return (Success => True, Error_Key => Null_Unbounded_String);
   end Execute_Drop_Import;

end Copy_Move;
