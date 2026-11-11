separate (Files.File_System)
function Create_Empty_File
  (Path : String)
   return Mutation_Result
is
   Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Identity : UString;
   Closed : Boolean;

begin
   Files.Io_Errors.Reset;
   declare
      Checked : constant Mutation_Result := Validate_New_Entry (Path, "error.file.parent_missing");
   begin
      if not Checked.Success then
         return Checked;
      end if;
   end;

   --  0666 less the creation mask, as GNAT's Create_New_File makes it.
   Descriptor := Hostkit.Regular_Files.Create_New (Path, 8#666#);
   if Descriptor = GNAT.OS_Lib.Invalid_FD then
      --  Before the existence check, whose own calls overwrite errno.
      Files.Io_Errors.Capture;
      if Files.Fs_Primitives.Entry_Exists (Path) then
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
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
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
