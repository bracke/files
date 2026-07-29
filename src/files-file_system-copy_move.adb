with Files.File_System.Support;
with Ada.Strings.Unbounded;
with Ada.Directories;
with Files.Fs;

separate (Files.File_System)
package body Copy_Move is

   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String)
      return Mutation_Result is
   begin
      Copy_Tree (Source_Path, Destination_Path);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.copy.failed"));
   end Copy_Tree;

   function Delete_Permanently
     (Path : String)
      return Mutation_Result
   is
      function Unsafe_Target return Boolean is
      begin
         if Path = ""
           or else Path = "/"
           or else (Path'Length = 3 and then Path (Path'First + 1 .. Path'First + 2) = ":\")
         then
            return True;
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
      elsif not Ada.Directories.Exists (Path) then
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
         while Ada.Directories.Exists (To_String (Full)) or else Is_Claimed (To_String (Full)) loop
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
         O : constant String := Ada.Directories.Full_Name (Outer);
      begin
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
            if not Ada.Directories.Exists (Source_Text) then
               Plan.Valid := False;
               Plan.Error_Key := To_Unbounded_String ("error.drop.invalid_source");
               Result.Plans.Append (Plan);
               Result.Error_Key := Plan.Error_Key;
            else
               Leaf := To_Unbounded_String (Ada.Directories.Simple_Name (Source_Text));
               if not Valid_Leaf_Name (To_String (Leaf)) then
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
     (Plans : Drop_Import_Plan_Vectors.Vector)
      return Mutation_Result
   is
   begin
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

            --  Drop whatever a failed step left at this plan's destination, so a
            --  failure leaves the source as the single canonical copy -- not a
            --  partial tree stranded at the destination, and not a duplicate when
            --  the source delete fails after a completed cross-device copy.
            procedure Discard_Destination is
               Removed : constant Mutation_Result := Delete_Permanently (Destination_Path);
               pragma Unreferenced (Removed);
            begin
               null;
            end Discard_Destination;
         begin
            if Plan.Mode = Drop_Move then
               if Source_Path /= Destination_Path then
                  begin
                     Ada.Directories.Rename (Source_Path, Destination_Path);
                  exception
                     when others =>
                        Copy_Tree (Source_Path, Destination_Path);
                        declare
                           Delete_Result : constant Mutation_Result := Delete_Permanently (Source_Path);
                        begin
                           if not Delete_Result.Success then
                              Discard_Destination;
                              return Delete_Result;
                           end if;
                        end;
                  end;
               end if;
            else
               Copy_Tree (Source_Path, Destination_Path);
            end if;
         exception
            when others =>
               --  A copy raised partway (e.g. out of space); remove the partial
               --  destination before reporting failure. The source is untouched.
               Discard_Destination;
               return
                 (Success   => False,
                  Error_Key => To_Unbounded_String ("error.drop.failed"));
         end;
      end loop;

      return (Success => True, Error_Key => Null_Unbounded_String);
   end Execute_Drop_Import;

end Copy_Move;
