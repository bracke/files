with Files.File_System.Support;
with Ada.Strings.Unbounded;
with Ada.Directories;
with Ada.Text_IO;
with Files.Fs;
with Files.Platform;
with Ada.Strings.Fixed;
with Files.Platform.Metadata;

separate (Files.File_System)
package body Create is

   use type Ada.Directories.File_Kind;
   function Mutation_Leaf_Name (Path : String) return String;

   function Validate_Link_Destination
     (Link_Path : String)
      return Mutation_Result;

   function Mutation_Leaf_Name (Path : String) return String is
   begin
      if Path = "" then
         return "";
      end if;

      return Ada.Directories.Simple_Name (Path);
   exception
      when others =>
         return "";
   end Mutation_Leaf_Name;

   function Create_Empty_File
     (Path : String)
      return Mutation_Result
   is
      File    : Ada.Text_IO.File_Type;
      Created : Boolean := False;

      procedure Delete_Created_File_If_Present is
      begin
         if Created
           and then Files.Fs.File_Exists (Path)
         then
            Ada.Directories.Delete_File (Path);
         end if;
      exception
         when others =>
            null;
      end Delete_Created_File_If_Present;

      function Parent_Directory return String is
      begin
         return Ada.Directories.Containing_Directory (Path);
      exception
         when others =>
            return "";
      end Parent_Directory;

      Parent : constant String := Parent_Directory;
      Name   : constant String := Mutation_Leaf_Name (Path);
   begin
      if Path = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.parent_missing"));
      elsif not Valid_Leaf_Name_At (Name, Parent) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.name.invalid"));
      elsif Ada.Directories.Exists (Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.exists"));
      elsif Parent = ""
        or else not Ada.Directories.Exists (Parent)
        or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.parent_missing"));
      end if;

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Created := True;
      Ada.Text_IO.Close (File);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         Safe_Close (File);
         Delete_Created_File_If_Present;
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.create"));
   end Create_Empty_File;

   function Create_Directory
     (Path : String)
      return Mutation_Result
   is
      function Parent_Directory return String is
      begin
         return Ada.Directories.Containing_Directory (Path);
      exception
         when others =>
            return "";
      end Parent_Directory;

      Parent : constant String := Parent_Directory;
      Name   : constant String := Mutation_Leaf_Name (Path);
   begin
      if Path = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.parent_missing"));
      elsif not Valid_Leaf_Name_At (Name, Parent) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.name.invalid"));
      elsif Ada.Directories.Exists (Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.exists"));
      elsif Parent = ""
        or else not Ada.Directories.Exists (Parent)
        or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.parent_missing"));
      end if;

      Ada.Directories.Create_Directory (Path);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.create"));
   end Create_Directory;

   function Rename_Item
     (From_Path : String;
      To_Path   : String)
      return Mutation_Result
   is
      function Exists_Safely (Path : String) return Boolean is
      begin
         return Path /= "" and then Files.Fs.Exists (Path);
      exception
         when others =>
            return False;
      end Exists_Safely;

      function Same_Existing_Path return Boolean is
      begin
         if From_Path = "" or else To_Path = "" then
            return False;
         end if;

         --  A no-op rename: the destination is the very same file AND its leaf
         --  is spelled identically, so there is nothing to change. A case-only
         --  rename (same file on a case-insensitive filesystem, but a different
         --  leaf case) deliberately fails this and is handled separately, no
         --  matter whether Full_Name canonicalises case on the host.
         return Exists_Safely (From_Path)
           and then Exists_Safely (To_Path)
           and then Files.Platform.Metadata.Same_File (From_Path, To_Path)
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
      begin
         return Exists_Safely (To_Path)
           and then Files.Platform.Metadata.Same_File (From_Path, To_Path)
           and then Files.Types.To_Lower (Mutation_Leaf_Name (From_Path))
                    = Files.Types.To_Lower (Mutation_Leaf_Name (To_Path))
           and then Mutation_Leaf_Name (From_Path) /= Mutation_Leaf_Name (To_Path);
      exception
         when others =>
            return False;
      end Is_Case_Only_Rename;

      --  Perform a case-only rename through a scratch name: From -> Temp -> To.
      --  On a case-insensitive filesystem the first hop frees the old spelling so
      --  the second lands on a now-vacant destination. Crucially there is NO
      --  Copy_Tree + delete fallback here: on any failure the file is put back
      --  under its original name, so a case-only rename can never lose data.
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

         Ada.Directories.Rename (From_Path, To_String (Temp));

         begin
            Ada.Directories.Rename (To_String (Temp), To_Path);
            return (Success => True, Error_Key => Null_Unbounded_String);
         exception
            when others =>
               --  Second hop failed: restore the original name so the file is
               --  never stranded at the scratch name.
               begin
                  Ada.Directories.Rename (To_String (Temp), From_Path);
               exception
                  when others =>
                     null;
               end;
               return
                 (Success   => False,
                  Error_Key => To_Unbounded_String ("error.rename.failed"));
         end;
      exception
         when others =>
            --  First hop failed: nothing moved.
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
   begin
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
      elsif not Valid_Leaf_Name_At (Name, Parent) then
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

      Ada.Directories.Rename (From_Path, To_Path);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         --  Ada.Directories.Rename cannot move across filesystems (EXDEV). Fall
         --  back to copy + delete, exactly as Execute_Drop_Import and
         --  Move_To_Trash do, so a cross-device move -- and, crucially, the undo
         --  of one (Move_Back routes through here) -- still succeeds instead of
         --  failing and stranding the file at the destination.
         declare
            Copied : constant Mutation_Result := Copy_Tree (From_Path, To_Path);

            --  On any failure once the copy has started, drop whatever it left at
            --  the destination so the source stays the single canonical copy: no
            --  partial tree stranded, and no duplicate if the source delete fails.
            procedure Discard_Destination is
               Removed : constant Mutation_Result := Delete_Permanently (To_Path);
               pragma Unreferenced (Removed);
            begin
               null;
            end Discard_Destination;
         begin
            if not Copied.Success then
               Discard_Destination;
               return
                 (Success   => False,
                  Error_Key => To_Unbounded_String ("error.rename.failed"));
            end if;

            declare
               Deleted : constant Mutation_Result := Delete_Permanently (From_Path);
            begin
               if not Deleted.Success then
                  Discard_Destination;
                  return Deleted;
               end if;
            end;

            return (Success => True, Error_Key => Null_Unbounded_String);
         exception
            when others =>
               Discard_Destination;
               return
                 (Success   => False,
                  Error_Key => To_Unbounded_String ("error.rename.failed"));
         end;
   end Rename_Item;

   --  Shared destination validation for the create-link commands: the new link
   --  path must be a valid, currently-unused leaf inside an existing directory.
   function Validate_Link_Destination
     (Link_Path : String)
      return Mutation_Result
   is
      function Parent_Directory return String is
      begin
         return Ada.Directories.Containing_Directory (Link_Path);
      exception
         when others =>
            return "";
      end Parent_Directory;

      Parent : constant String := Parent_Directory;
      Name   : constant String := Mutation_Leaf_Name (Link_Path);
   begin
      if Link_Path = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
      elsif not Valid_Leaf_Name_At (Name, Parent) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.name.invalid"));
      elsif Ada.Directories.Exists (Link_Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.exists"));
      elsif Parent = ""
        or else not Ada.Directories.Exists (Parent)
        or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.parent_missing"));
      end if;

      return (Success => True, Error_Key => Null_Unbounded_String);
   end Validate_Link_Destination;

   function Create_Symbolic_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result
   is
      Validation : constant Mutation_Result := Validate_Link_Destination (Link_Path);
   begin
      if Source_Path = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
      elsif not Validation.Success then
         return Validation;
      elsif Files.Platform.Metadata.Create_Symbolic_Link (Source_Path, Link_Path) then
         return (Success => True, Error_Key => Null_Unbounded_String);
      else
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
      end if;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
   end Create_Symbolic_Link;

   function Create_Hard_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result
   is
      Validation : constant Mutation_Result := Validate_Link_Destination (Link_Path);
   begin
      if Source_Path = ""
        or else not Ada.Directories.Exists (Source_Path)
        or else Ada.Directories.Kind (Source_Path) = Ada.Directories.Directory
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
      elsif not Validation.Success then
         return Validation;
      elsif Files.Platform.Metadata.Create_Hard_Link (Source_Path, Link_Path) then
         return (Success => True, Error_Key => Null_Unbounded_String);
      else
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
      end if;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
   end Create_Hard_Link;

end Create;
