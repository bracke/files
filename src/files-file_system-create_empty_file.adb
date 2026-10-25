separate (Files.File_System)
function Create_Empty_File
  (Path : String)
   return Mutation_Result
is
   use type GNAT.OS_Lib.File_Descriptor;
   Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Identity : UString;
   Closed : Boolean;

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
   Files.Io_Errors.Reset;
   if Path = "" then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.file.parent_missing"));
   elsif not Valid_Leaf_Name_At (Name, Parent) then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.name.invalid"));
   elsif Ada.Directories.Exists (Path) or else Hostkit.Fs.Is_Link (Path) then
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

   Descriptor := GNAT.OS_Lib.Create_New_File (Path, GNAT.OS_Lib.Binary);
   if Descriptor = GNAT.OS_Lib.Invalid_FD then
      --  Before the existence check, whose own calls overwrite errno.
      Files.Io_Errors.Capture;
      if Ada.Directories.Exists (Path) or else Hostkit.Fs.Is_Link (Path) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.file.exists"));
      end if;
      raise Ada.Directories.Use_Error;
   end if;
   Identity := To_Unbounded_String (Files.File_Identities.Token (Path));
   GNAT.OS_Lib.Close (Descriptor, Closed);
   Descriptor := GNAT.OS_Lib.Invalid_FD;
   if not Closed then
      Files.Io_Errors.Capture;
      raise Ada.Directories.Use_Error;
   end if;
   return (Success => True, Error_Key => Null_Unbounded_String);
exception
   when others =>
      declare
         --  Chosen before the cleanup below can record a cause of its own.
         Failed : constant Mutation_Result :=
           (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.file.create"));
      begin
         if Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Descriptor);
         end if;
         if Length (Identity) > 0 then
            declare
               Removed : constant Mutation_Result := Delete_Created_Entry
                 (Path, To_String (Identity), Tree_Revision (Path));
               pragma Unreferenced (Removed);
            begin
               null;
            end;
         end if;
         return Failed;
      end;
end Create_Empty_File;
