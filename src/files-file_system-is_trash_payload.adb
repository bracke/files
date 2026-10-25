separate (Files.File_System)
--  Public trash operations must act only on direct children of this
--  environment's payload directory.  Besides protecting the public API,
--  this keeps a damaged history record from using a valid sidecar basename
--  to move or delete an unrelated entry elsewhere on the filesystem.
function Is_Trash_Payload (Path, Payload_Directory : String) return Boolean is
   Actual_Parent, Expected_Parent : Unbounded_String;
begin
   if not Valid_Original_Path (Path) or else Payload_Directory = "" then
      return False;
   end if;
   Actual_Parent := To_Unbounded_String
     (Hostkit.Fs.Real_Path (Ada.Directories.Containing_Directory (Path)));
   Expected_Parent := To_Unbounded_String
     (Hostkit.Fs.Real_Path (Payload_Directory));
   return Length (Actual_Parent) > 0
     and then Actual_Parent = Expected_Parent;
exception
   when others =>
      return False;
end Is_Trash_Payload;
