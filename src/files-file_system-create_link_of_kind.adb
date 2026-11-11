separate (Files.File_System)
function Create_Link_Of_Kind
  (Source_Path : String;
   Link_Path   : String;
   Hard        : Boolean)
   return Mutation_Result
is
   Validation : constant Mutation_Result := Validate_Link_Destination (Link_Path);
begin
   --  A hard link needs an existing non-directory (a link itself counts);
   --  a symbolic link may point anywhere, even at nothing.
   if Source_Path = ""
     or else (Hard
              and then not Hostkit.Fs.Is_Link (Source_Path)
              and then (not Files.Fs_Primitives.Exists (Source_Path)
                        or else Files.Fs_Primitives.Kind (Source_Path) = Ada.Directories.Directory))
   then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.link.failed"));
   elsif not Validation.Success then
      return Validation;
   end if;
   --  A full disk, a refused permission or a read-only volume is said as
   --  such, not as the generic failure.
   Files.Io_Errors.Reset;
   Files.Io_Errors.Clear_Os_Error;
   if (if Hard
       then Hostkit.Fs.Create_Hard_Link (Source_Path, Link_Path)
       else Hostkit.Fs.Create_Link (Source_Path, Link_Path))
   then
      return (Success => True, Error_Key => Null_Unbounded_String);
   end if;
   Files.Io_Errors.Capture;
   return (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.link.failed"));
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.link.failed"));
end Create_Link_Of_Kind;
