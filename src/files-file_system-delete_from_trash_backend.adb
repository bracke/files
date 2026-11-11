separate (Files.File_System)
function Delete_From_Trash_Backend
  (Trashed_Path : String)
   return Mutation_Result
is
   Removed : Mutation_Result;
   Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   --  The freedesktop trash (home or volume) that holds it; the macOS home
   --  trash has no info files.
   Base    : constant String := Trash_Base_Of (Trashed_Path);
begin
   --  A Recycle Bin item goes with its $I record, as Explorer's Delete does.
   if Backend = Trash_Windows_Recycle_Bin then
      if not Hostkit.Trash.Is_Recycled_Item (Trashed_Path) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
      elsif not Hostkit.Trash.Purge (Trashed_Path) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.permanent_delete.failed"));
      end if;
      return (Success => True, Error_Key => Null_Unbounded_String);
   end if;

   if Base = ""
     and then (Backend /= Trash_Macos_Home or else not Is_Trash_Payload (Trashed_Path, Trash_Files_Directory))
   then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.trash.failed"));
   end if;
   Removed := Delete_Permanently (Trashed_Path);
   if not Removed.Success then
      return Removed;
   end if;

   --  Freedesktop backends keep a <base>/info/<name>.trashinfo sidecar next
   --  to the payload; remove it so the emptied entry leaves no orphaned
   --  metadata. Sidecar removal is best-effort and never fails the purge.
   if Base /= "" then
      declare
         Simple    : constant String := Files.Fs_Primitives.Leaf_Text (Trashed_Path);
         Info_Path : constant String :=
           Hostkit.Fs.Join (Hostkit.Fs.Join (Base, "info"), Simple & ".trashinfo");
      begin
         if Files.Fs_Primitives.Exists (Info_Path) then
            Files.Fs_Primitives.Delete_File (Info_Path);
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System");
      end;
   end if;

   return Removed;
end Delete_From_Trash_Backend;
